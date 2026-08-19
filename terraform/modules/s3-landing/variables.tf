variable "bucket_name" {
  description = "Name of the S3 landing bucket for raw scorecard uploads"
  type        = string
}

variable "kms_key_alias" {
  description = "Alias for the KMS CMK used to encrypt objects in the landing bucket"
  type        = string
  default     = "cricket-scorecards-landing"
}

variable "uploader_user_name" {
  description = "Name of the IAM user used by the local-sync launchd job to upload scorecards"
  type        = string
  default     = "cricket-scorecards-uploader"
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
