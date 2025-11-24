variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "employee_api_url" {
  description = "URL of the Employee API (Component 2)"
  type        = string
}

# Comma‑separated list of IAM roles to grant (e.g. "roles/viewer,roles/storage.objectViewer,roles/compute.osLogin")
variable "target_roles" {
  description = "IAM roles to assign to employees"
  type        = string
  default     = "roles/viewer"
}

variable "schedule_cron" {
  description = "Cron schedule for the sync job"
  type        = string
  default     = "0 * * * *" # Hourly
}

variable "oauth_client_id" {
  description = "OAuth2 client ID for Employee API authentication"
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth2 client secret for Employee API authentication"
  type        = string
  sensitive   = true
}
