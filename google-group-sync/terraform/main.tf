terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iamcredentials.googleapis.com", # Critical for Keyless DWD
    "admin.googleapis.com",          # For Admin SDK (Legacy)
    "cloudidentity.googleapis.com"   # For Cloud Identity Groups (Modern)
  ])

  project = var.project_id
  service = each.key
  disable_on_destroy = false
}
