# Artifact Registry Repository
resource "google_artifact_registry_repository" "employee_api" {
  location      = var.region
  repository_id = var.app_name
  description   = "Docker repository for Employee API"
  format        = "DOCKER"
  
  labels = {
    app         = var.app_name
    environment = "production"
    managed-by  = "terraform"
  }
}

# IAM binding for Cloud Build to push images
resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  location   = google_artifact_registry_repository.employee_api.location
  repository = google_artifact_registry_repository.employee_api.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# IAM binding for GKE to pull images
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  location   = google_artifact_registry_repository.employee_api.location
  repository = google_artifact_registry_repository.employee_api.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}
