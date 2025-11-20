variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "suman-110797"
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

# Cloud SQL Proxy Variables
variable "allowed_ips" {
  description = "List of IP addresses allowed to connect to the proxy (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "dns_domain" {
  description = "Domain name for the DNS zone (e.g., example.com)"
  type        = string
  default     = "jupyterhub-proxy.com"
}

variable "db_password" {
  description = "Password for the postgres_user database user"
  type        = string
  default     = "postgres"
}
