resource "google_service_account" "sync_sa" {
  account_id   = "group-sync-sa"
  display_name = "Citadel IAM Sync Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "sa_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.sync_sa.email}"
}
