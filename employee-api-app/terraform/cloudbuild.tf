# Enable required APIs
resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"
  
  disable_on_destroy = false
}

# Note: Cloud Build trigger requires a source repository configuration
# For now, we'll skip the trigger and use manual builds with gcloud
# Uncomment and configure when you have a GitHub repository

# resource "google_cloudbuild_trigger" "employee_api_build" {
#   project     = var.project_id
#   name        = "${var.app_name}-build-deploy"
#   description = "Build and deploy Employee API to GKE"
#   
#   github {
#     owner = "your-github-username"
#     name  = "your-repo-name"
#     push {
#       branch = "^main$"
#     }
#   }
#   
#   filename = "cloudbuild.yaml"
#   
#   substitutions = {
#     _PROJECT_ID    = var.project_id
#     _REGION        = var.region
#     _REPO_NAME     = var.app_name
#     _IMAGE_NAME    = var.app_name
#     _IMAGE_TAG     = var.image_tag
#     _CLUSTER_NAME  = var.cluster_name
#     _CLUSTER_ZONE  = var.cluster_location
#     _NAMESPACE     = var.namespace
#   }
#   
#   depends_on = [
#     google_project_service.cloudbuild,
#     google_artifact_registry_repository.employee_api
#   ]
# }

# IAM permissions for Cloud Build
resource "google_project_iam_member" "cloudbuild_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
