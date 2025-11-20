output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}

output "kubernetes_cluster_host" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Cluster Host"
}

output "cloudsql_connection_name" {
  value = google_sql_database_instance.instance.connection_name
}

output "cloudsql_private_ip" {
  value = google_sql_database_instance.instance.private_ip_address
}

output "db_user" {
  value = google_sql_user.iam_user.name
}

output "postgres_password" {
  value     = random_password.postgres_password.result
  sensitive = true
  description = "Password for postgres user (needed for granting permissions)"
}

output "region" {
  value       = var.region
  description = "GKE Region"
}

output "project_id" {
  value       = var.project_id
  description = "GCP Project ID"
}

output "shared_bucket_name" {
  value       = google_storage_bucket.shared_bucket.name
  description = "The name of the shared GCS bucket"
}

output "jupyter_user_sa_email" {
  value       = google_service_account.jupyter_user_sa.email
  description = "The email of the Google Service Account for Jupyter users"
}

# Cloud SQL Proxy Outputs
output "proxy_public_ip" {
  description = "Public IP address of the Cloud SQL Proxy VM"
  value       = google_compute_instance.proxy_vm.network_interface[0].access_config[0].nat_ip
}

output "proxy_connection_command" {
  description = "Command to connect to the database via the proxy"
  value       = "psql -h ${google_compute_instance.proxy_vm.network_interface[0].access_config[0].nat_ip} -p 5432 -U postgres_user -d jupyterhub_db"
}

output "dns_connection_address" {
  description = "DNS address to connect to (requires domain ownership)"
  value       = "db.${var.dns_domain}"
}
