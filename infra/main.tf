terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  # Use a zonal cluster to save quota (1 zone instead of 3)
  location = "${var.region}-a"
  
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable GCS FUSE CSI Driver
  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Enable Cloud Logging and Monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Network configuration
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = "${var.region}-a"
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = "jupyterhub"
    }

    # Preemptible nodes are cheaper, but for persistence/stability standard is better.
    # Using standard for this request.
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-standard"

    # Enable Workload Identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    
    # Secure Boot (Optional but recommended)
    shielded_instance_config {
      enable_secure_boot = true
    }
  }
}

# Shared GCS Bucket
resource "google_storage_bucket" "shared_bucket" {
  name          = "${var.project_id}-jupyterhub-shared"
  location      = var.region
  force_destroy = true # For demo purposes, allows deleting non-empty bucket
  uniform_bucket_level_access = true
}

# Service Account for JupyterHub Users to access the bucket
resource "google_service_account" "jupyter_user_sa" {
  account_id   = "jupyter-user-sa"
  display_name = "JupyterHub User Service Account"
}

# Grant SA access to the bucket
resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.shared_bucket.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.jupyter_user_sa.email}",
  ]
}

# Allow Kubernetes Service Account to impersonate Google Service Account (Workload Identity)
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.jupyter_user_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[jhub/jupyter-user-sa]",
  ]
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "192.168.0.0/24"
}

# Private IP for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Cloud SQL Instance
resource "google_sql_database_instance" "instance" {
  name             = "jupyterhub-db-instance"
  region           = var.region
  database_version = "POSTGRES_15"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    
    # Enable IAM authentication
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }
  deletion_protection = false
}

# Database
resource "google_sql_database" "database" {
  name     = "jupyterhub_db"
  instance = google_sql_database_instance.instance.name
}

# IAM Binding for Service Account to be a Cloud SQL User
resource "google_sql_user" "iam_user" {
  name     = trimsuffix(google_service_account.jupyter_user_sa.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Random password for postgres user (for initial setup)
resource "random_password" "postgres_password" {
  length  = 16
  special = true
}

# Postgres user for granting permissions
resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.instance.name
  password = random_password.postgres_password.result
}

# Grant Cloud SQL Client role to the SA
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.jupyter_user_sa.email}"
}

# Grant Cloud SQL Instance User role to the SA
resource "google_project_iam_member" "cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.jupyter_user_sa.email}"
}
