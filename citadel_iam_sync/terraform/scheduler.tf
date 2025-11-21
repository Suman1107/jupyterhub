resource "google_cloud_scheduler_job" "sync_job" {
  name        = "citadel-iam-sync-job"
  description = "Triggers the Citadel IAM Sync Cloud Function hourly"
  schedule    = var.schedule_cron
  time_zone   = "UTC"
  attempt_deadline = "320s"
  region      = var.region

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.sync_function.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.sync_sa.email
    }
  }

  depends_on = [google_cloudfunctions2_function.sync_function]
}
