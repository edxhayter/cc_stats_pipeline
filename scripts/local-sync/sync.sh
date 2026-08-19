#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
LOG_FILE="$SCRIPT_DIR/sync.log"

# launchd's default environment doesn't include Homebrew's PATH, so it can't
# find `aws` by name — call it by full path instead.
AWS_BIN="/usr/local/bin/aws"

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >>"$LOG_FILE"
}

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: missing $ENV_FILE"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${aws_access_key_id:-}" || -z "${aws_secret_access_key:-}" || -z "${source_dir:-}" || -z "${s3_bucket:-}" ]]; then
  log "ERROR: aws_access_key_id / aws_secret_access_key / source_dir / s3_bucket not all set in $ENV_FILE"
  exit 1
fi

SOURCE_DIR="$source_dir"
S3_BUCKET="$s3_bucket"
S3_PREFIX="${s3_prefix:-}"

export AWS_ACCESS_KEY_ID="$aws_access_key_id"
export AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"

log "sync started: \"$SOURCE_DIR\" -> s3://$S3_BUCKET/$S3_PREFIX"

# --sse aws:kms (no --sse-kms-key-id): the bucket policy denies any upload
# whose x-amz-server-side-encryption header isn't "aws:kms", so the header
# must be present — but the specific key ID is deliberately left unset. Per
# AWS's docs, when no key is given in the request, S3 falls back to the
# bucket's own default-encryption CMK. That way this script never hardcodes
# a key ARN that can go stale if the key is ever rotated.
if "$AWS_BIN" s3 sync "$SOURCE_DIR" "s3://$S3_BUCKET/$S3_PREFIX" \
  --sse aws:kms \
  --only-show-errors >>"$LOG_FILE" 2>&1; then
  log "sync completed successfully"
else
  status=$?
  log "ERROR: sync failed with exit code $status"
  exit "$status"
fi
