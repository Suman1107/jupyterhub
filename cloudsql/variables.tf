variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the VM instance"
  type        = string
  default     = "us-central1-a"
}

variable "vpc_name" {
  description = "Name of the VPC network (should match your existing VPC)"
  type        = string
  default     = "suman-110797-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet (should match your existing subnet)"
  type        = string
  default     = "suman-110797-subnet"
}

variable "cloudsql_instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "jupyterhub-db-instance"
}

variable "cloudsql_connection_name" {
  description = "Cloud SQL connection name (project:region:instance)"
  type        = string
  # Format: project_id:region:instance_name
  # This will be constructed in main.tf if not provided
  default = ""
}

variable "allowed_ips" {
  description = "List of IP addresses allowed to connect to the proxy (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Change this to your specific IP for security!
}

variable "machine_type" {
  description = "Machine type for the proxy VM"
  type        = string
  default     = "e2-micro" # Smallest instance type
}

variable "proxy_vm_name" {
  description = "Name of the Cloud SQL Proxy VM"
  type        = string
  default     = "cloudsql-proxy-vm"
}

variable "service_account_name" {
  description = "Name of the service account for Cloud SQL Proxy"
  type        = string
  default     = "cloudsql-proxy"
}

variable "enable_ssh" {
  description = "Enable SSH access to the proxy VM for debugging"
  type        = bool
  default     = true
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 10 # Minimal size
}
