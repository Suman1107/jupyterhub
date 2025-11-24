variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "suman-110797"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the existing GKE cluster"
  type        = string
  default     = "jupyterhub-cluster"
}

variable "cluster_location" {
  description = "Location of the GKE cluster (zone or region)"
  type        = string
  default     = "us-central1-a"
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "employee-api"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "employee-api"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of replicas for HPA"
  type        = number
  default     = 10
}

variable "storage_size" {
  description = "Size of persistent volume for database"
  type        = string
  default     = "1Gi"
}
