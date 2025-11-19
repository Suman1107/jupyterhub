variable "project_id" {
  description = "The project ID to host the cluster in"
}

variable "region" {
  description = "The region to host the cluster in"
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  default     = "jupyterhub-cluster"
}
