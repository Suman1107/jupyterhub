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
