terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  connection_name = var.cloudsql_connection_name != "" ? var.cloudsql_connection_name : "${var.project_id}:${var.region}:${var.cloudsql_instance_name}"
}

# ------------------------------------------------------------------------------
# Service Account
# ------------------------------------------------------------------------------

resource "google_service_account" "proxy_sa" {
  account_id   = var.service_account_name
  display_name = "Cloud SQL Proxy Service Account"
}

resource "google_project_iam_member" "client_role" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.proxy_sa.email}"
}

resource "google_project_iam_member" "instance_user_role" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.proxy_sa.email}"
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------

# Static Public IP for the Proxy
resource "google_compute_address" "static_ip" {
  name = "cloudsql-proxy-ip"
}

# Public VPC for external access (NIC0)
# We create a separate VPC for the public interface to keep it isolated
resource "google_compute_network" "public_vpc" {
  name                    = "cloudsql-proxy-public-vpc"
  auto_create_subnetworks = true
}

# Data source for the existing Private VPC (NIC1)
# This is where the Cloud SQL instance lives
data "google_compute_network" "private_vpc" {
  name = var.vpc_name
}

data "google_compute_subnetwork" "private_subnet" {
  name   = var.subnet_name
  region = var.region
}

# ------------------------------------------------------------------------------
# Firewall Rules
# ------------------------------------------------------------------------------

# Allow PostgreSQL traffic from allowed IPs to the Proxy VM (Public NIC)
resource "google_compute_firewall" "allow_postgres" {
  name    = "allow-postgres-proxy"
  network = google_compute_network.public_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = var.allowed_ips
  target_tags   = ["cloudsql-proxy"]
}

# Allow SSH traffic (Optional)
resource "google_compute_firewall" "allow_ssh" {
  count   = var.enable_ssh ? 1 : 0
  name    = "allow-ssh-proxy"
  network = google_compute_network.public_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ips
  target_tags   = ["cloudsql-proxy"]
}

# ------------------------------------------------------------------------------
# Compute Instance
# ------------------------------------------------------------------------------

resource "google_compute_instance" "proxy_vm" {
  name         = var.proxy_vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = var.boot_disk_size_gb
    }
  }

  # NIC0: Public Network (Default Route)
  # This interface receives traffic from the internet (your computer)
  network_interface {
    network = google_compute_network.public_vpc.name
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  # NIC1: Private Network (Access to DB)
  # This interface communicates with Cloud SQL via Private IP
  network_interface {
    network    = data.google_compute_network.private_vpc.name
    subnetwork = data.google_compute_subnetwork.private_subnet.name
  }

  service_account {
    email  = google_service_account.proxy_sa.email
    scopes = ["cloud-platform"]
  }

  # Startup script to install and run Cloud SQL Proxy
  metadata_startup_script = templatefile("${path.module}/startup-script.sh.tftpl", {
    CONNECTION_NAME = local.connection_name
  })

  tags = ["cloudsql-proxy"]
}

# ------------------------------------------------------------------------------
# DNS (Optional)
# ------------------------------------------------------------------------------

# Create a DNS Zone (e.g., proxy.jupyterhub)
# NOTE: For this to work publicly, you must own the domain and update nameservers.
resource "google_dns_managed_zone" "proxy_zone" {
  name        = "jupyterhub-proxy-zone"
  dns_name    = "${var.dns_domain}."
  description = "DNS zone for JupyterHub Proxy"
  visibility  = "public"
}

# Create an A record pointing to the Proxy IP
resource "google_dns_record_set" "proxy_record" {
  name         = "db.${google_dns_managed_zone.proxy_zone.dns_name}"
  managed_zone = google_dns_managed_zone.proxy_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_instance.proxy_vm.network_interface[0].access_config[0].nat_ip]
}

# ------------------------------------------------------------------------------
# Database User (Automated Access)
# ------------------------------------------------------------------------------

# Create a dedicated user for external access so we don't need manual steps
resource "google_sql_user" "proxy_user" {
  name     = "postgres_user"
  instance = var.cloudsql_instance_name
  password = var.db_password
  project  = var.project_id
}
