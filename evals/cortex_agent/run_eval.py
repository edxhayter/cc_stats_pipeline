"""Run the Cortex Agent evaluation end to end and summarise the scores.

Used by .github/workflows/agent-evals.yml; also runnable locally. Steps:
  1. Create the eval dataset if the version named in the config doesn't
     exist yet (executes eval_cases.sql).
  2. Upload agent_evaluation_config.yaml to the config stage.
  3. Start the run and poll until it finishes.
  4. Pull per-record scores, write a Markdown summary (to
     $GITHUB_STEP_SUMMARY when set) and a JSON file of the raw rows.

Report-only by default: exits non-zero only when the run itself fails.
Pass --min-answer-correctness to turn it into a gate once there's a
baseline.

Connection settings come from the environment: SNOWFLAKE_ACCOUNT,
SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY (PEM text), optional
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE, SNOWFLAKE_ROLE, SNOWFLAKE_WAREHOUSE,
SNOWFLAKE_DATABASE, SNOWFLAKE_SCHEMA (the agent's schema).
"""

import argparse
import json
import os
import re
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import snowflake.connector
from cryptography.hazmat.primitives import serialization

HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "agent_evaluation_config.yaml"
CASES_SQL_PATH = HERE / "eval_cases.sql"
CASES_TABLE = "CRICKET_AGENT_EVAL_CASES"
CONFIG_STAGE = "AGENT_EVAL_CONFIG"  # terraform/envs/prod/agent_evals.tf
TERMINAL_STATUSES = {"COMPLETED", "PARTIALLY_COMPLETED", "CANCELLED"}


def config_value(key):
    match = re.search(rf'^\s*{key}:\s*"([^"]+)"', CONFIG_PATH.read_text(), re.M)
    if not match:
        sys.exit(f"{key} not found in {CONFIG_PATH.name}")
    return match.group(1)


def connect():
    passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE") or None
    key = serialization.load_pem_private_key(
        os.environ["SNOWFLAKE_PRIVATE_KEY"].encode(),
        password=passphrase.encode() if passphrase else None,
    )
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ),
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema=os.environ["SNOWFLAKE_SCHEMA"],
    )


def ensure_dataset(conn, dataset_name):
    cases_sql = CASES_SQL_PATH.read_text()
    if f".{dataset_name}'" not in cases_sql:
        sys.exit(
            f"{CASES_SQL_PATH.name} doesn't create {dataset_name} — bump the "
            f"version in both files together."
        )
    cur = conn.cursor()
    cur.execute(f"SHOW DATASETS LIKE '{dataset_name}' IN SCHEMA")
    if cur.fetchall():
        print(f"Dataset {dataset_name} exists.")
        return
    print(f"Dataset {dataset_name} not found; creating from {CASES_SQL_PATH.name}.")
    for result in conn.execute_string(cases_sql):
        result.fetchall()


def upload_config(conn):
    conn.cursor().execute(
        f"PUT 'file://{CONFIG_PATH}' @{CONFIG_STAGE} "
        f"AUTO_COMPRESS = FALSE OVERWRITE = TRUE"
    )


def evaluation_call(conn, job, run_name):
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute(
        "CALL EXECUTE_AI_EVALUATION(%s, OBJECT_CONSTRUCT('run_name', %s), %s)",
        (job, run_name, f"@{CONFIG_STAGE}/{CONFIG_PATH.name}"),
    )
    return cur.fetchall()


def wait_for_run(conn, run_name, timeout_s, poll_s):
    deadline = time.monotonic() + timeout_s
    last = None
    while time.monotonic() < deadline:
        rows = evaluation_call(conn, "STATUS", run_name)
        status = rows[0]["STATUS"] if rows else "UNKNOWN"
        if status != last:
            print(f"{datetime.now(timezone.utc):%H:%M:%S} {status}")
            last = status
        if status in TERMINAL_STATUSES:
            return status, rows[0].get("STATUS_DETAILS")
        time.sleep(poll_s)
    evaluation_call(conn, "CANCEL", run_name)
    sys.exit(f"Run {run_name} didn't finish within {timeout_s}s; cancelled.")


def fetch_results(conn, agent_name, run_name):
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute(
        f"""
        SELECT c.case_id, c.category, e.input, e.output, e.error,
               e.metric_name, e.eval_agg_score
        FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
            CURRENT_DATABASE(), CURRENT_SCHEMA(), %s, 'CORTEX AGENT', %s)) e
        LEFT JOIN {CASES_TABLE} c ON c.input_query = e.input
        ORDER BY c.category, c.case_id, e.metric_name
        """,
        (agent_name, run_name),
    )
    return cur.fetchall()


def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else None


def fmt(score):
    return "—" if score is None else f"{score:.2f}"


def summarise(rows, run_name, status, details):
    metrics = sorted({r["METRIC_NAME"] for r in rows if r["METRIC_NAME"]})
    by_metric = defaultdict(list)
    by_category = defaultdict(lambda: defaultdict(list))
    by_case = defaultdict(dict)
    errors = {}
    for r in rows:
        case = r["CASE_ID"] or r["INPUT"][:60]
        by_metric[r["METRIC_NAME"]].append(r["EVAL_AGG_SCORE"])
        by_category[r["CATEGORY"] or "unmatched"][r["METRIC_NAME"]].append(r["EVAL_AGG_SCORE"])
        by_case[(r["CATEGORY"] or "unmatched", case)][r["METRIC_NAME"]] = r["EVAL_AGG_SCORE"]
        if r["ERROR"]:
            errors[case] = r["ERROR"]

    lines = [
        "## Cortex Agent evals",
        "",
        f"Run `{run_name}` finished with status **{status}**. Report-only: scores don't fail the pipeline.",
        "",
        "| Metric | Mean |",
        "|---|---|",
        *[f"| {m} | {fmt(mean(by_metric[m]))} |" for m in metrics],
        "",
        "| Category | " + " | ".join(metrics) + " |",
        "|---|" + "---|" * len(metrics),
        *[
            f"| {cat} | " + " | ".join(fmt(mean(scores[m])) for m in metrics) + " |"
            for cat, scores in sorted(by_category.items())
        ],
        "",
        "<details><summary>Per case</summary>",
        "",
        "| Category | Case | " + " | ".join(metrics) + " |",
        "|---|---|" + "---|" * len(metrics),
        *[
            f"| {cat} | {case} | " + " | ".join(fmt(scores.get(m)) for m in metrics) + " |"
            for (cat, case), scores in sorted(by_case.items())
        ],
        "",
        "</details>",
    ]
    if errors or details:
        lines += ["", "### Errors", ""]
        lines += [f"- **{case}**: {err}" for case, err in errors.items()]
        if details:
            lines.append(f"- Run status details: `{json.dumps(details, default=str)}`")
    return "\n".join(lines) + "\n", mean(by_metric.get("answer_correctness", []))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--run-name", default=None)
    parser.add_argument("--timeout", type=int, default=45 * 60, help="seconds")
    parser.add_argument("--poll", type=int, default=30, help="seconds")
    parser.add_argument("--results-json", default="agent_eval_results.json")
    parser.add_argument(
        "--min-answer-correctness",
        type=float,
        default=None,
        help="fail if mean answer_correctness is below this (off by default)",
    )
    args = parser.parse_args()

    sha = os.environ.get("GITHUB_SHA", "local")[:7]
    run_name = args.run_name or f"ci-{sha}-{datetime.now(timezone.utc):%Y%m%d-%H%M%S}"
    agent_name = config_value("agent_name")
    dataset_name = config_value("dataset_name")

    with connect() as conn:
        ensure_dataset(conn, dataset_name)
        upload_config(conn)
        print(f"Starting run {run_name} against {agent_name} / {dataset_name}.")
        print(evaluation_call(conn, "START", run_name))
        status, details = wait_for_run(conn, run_name, args.timeout, args.poll)
        if status == "CANCELLED":
            sys.exit(f"Run {run_name} was cancelled: {details}")
        rows = fetch_results(conn, agent_name, run_name)

    Path(args.results_json).write_text(json.dumps(rows, default=str, indent=2))
    summary, answer_correctness = summarise(rows, run_name, status, details)
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(summary)

    if args.min_answer_correctness is not None and (
        answer_correctness is None or answer_correctness < args.min_answer_correctness
    ):
        sys.exit(
            f"Mean answer_correctness {fmt(answer_correctness)} is below "
            f"{args.min_answer_correctness}."
        )


if __name__ == "__main__":
    main()
