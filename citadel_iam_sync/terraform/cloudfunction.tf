# Zip the source code
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "/tmp/function-source.zip"
}

# Bucket to hold the zip
resource "google_storage_bucket" "source_bucket" {
  name                        = "${var.project_id}-gcf-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "zip" {
  name   = "source-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.source.output_path
}

# Cloud Function (Gen1)
resource "google_cloudfunctions_function" "sync_function" {
  name        = "citadel-iam-sync"
  description = "Sync Employee API to GCP IAM (Citadel)"
  runtime     = "python311"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.source_bucket.name
  source_archive_object = google_storage_bucket_object.zip.name
  trigger_http          = true
  entry_point           = "sync_iam"
  timeout               = 60
  service_account_email = google_service_account.sync_sa.email

  environment_variables = {
    EMPLOYEE_API_URL = var.employee_api_url
    TARGET_ROLES     = var.target_roles
    PROJECT_ID       = var.project_id
  }

  depends_on = [google_project_service.apis]
}
