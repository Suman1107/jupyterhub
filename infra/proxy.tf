# ------------------------------------------------------------------------------
# Cloud SQL Proxy Infrastructure
# ------------------------------------------------------------------------------

# Service Account for Proxy
resource "google_service_account" "proxy_sa" {
  account_id   = "cloudsql-proxy"
  display_name = "Cloud SQL Proxy Service Account"
}

resource "google_project_iam_member" "proxy_client_role" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.proxy_sa.email}"
}

resource "google_project_iam_member" "proxy_instance_user_role" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.proxy_sa.email}"
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------

# Static Public IP for the Proxy
resource "google_compute_address" "proxy_static_ip" {
  name = "cloudsql-proxy-ip"
}

# Public VPC for external access (NIC0)
resource "google_compute_network" "proxy_public_vpc" {
  name                    = "cloudsql-proxy-public-vpc"
  auto_create_subnetworks = true
}

# Firewall Rules
resource "google_compute_firewall" "allow_postgres_proxy" {
  name    = "allow-postgres-proxy"
  network = google_compute_network.proxy_public_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = var.allowed_ips
  target_tags   = ["cloudsql-proxy"]
}

resource "google_compute_firewall" "allow_ssh_proxy" {
  name    = "allow-ssh-proxy"
  network = google_compute_network.proxy_public_vpc.name

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
  name         = "cloudsql-proxy-vm"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
    }
  }

  # NIC0: Public Network (Default Route)
  network_interface {
    network = google_compute_network.proxy_public_vpc.name
    access_config {
      nat_ip = google_compute_address.proxy_static_ip.address
    }
  }

  # NIC1: Private Network (Access to DB)
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name
  }

  service_account {
    email  = google_service_account.proxy_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/startup-script.sh.tftpl", {
    CONNECTION_NAME = google_sql_database_instance.instance.connection_name
  })

  tags = ["cloudsql-proxy"]
}

# ------------------------------------------------------------------------------
# DNS
# ------------------------------------------------------------------------------

resource "google_dns_managed_zone" "proxy_zone" {
  name        = "jupyterhub-proxy-zone"
  dns_name    = "${var.dns_domain}."
  description = "DNS zone for JupyterHub Proxy"
  visibility  = "public"
}

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

resource "google_sql_user" "proxy_user" {
  name     = "postgres_user"
  instance = google_sql_database_instance.instance.name
  password = var.db_password
}
