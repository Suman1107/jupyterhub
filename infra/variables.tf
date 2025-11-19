variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_id_number" {
  description = "GCP Project Number (for service account references)"
  type        = string
  default     = "255196298928"  # Update this for your project
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "jupyterhub-cluster"
}
