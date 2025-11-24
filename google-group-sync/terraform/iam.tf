resource "google_service_account" "sync_sa" {
  account_id   = "group-sync-sa"
  display_name = "Google Group Sync Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "sa_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.sync_sa.email}"
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = var.project_id
  region         = var.region
  cloud_function = google_cloudfunctions_function.sync_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.sync_sa.email}"
}
