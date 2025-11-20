output "proxy_public_ip" {
  description = "Public IP address of the Cloud SQL Proxy VM"
  value       = google_compute_instance.proxy_vm.network_interface[0].access_config[0].nat_ip
}

output "proxy_vm_name" {
  description = "Name of the Proxy VM"
  value       = google_compute_instance.proxy_vm.name
}

output "service_account_email" {
  description = "Email of the created Service Account"
  value       = google_service_account.proxy_sa.email
}

output "connection_command" {
  description = "Command to connect to the database via the proxy"
  value       = "psql -h ${google_compute_instance.proxy_vm.network_interface[0].access_config[0].nat_ip} -p 5432 -U postgres_user -d jupyterhub_db"
}

output "db_username" {
  description = "Automated database user for external access"
  value       = google_sql_user.proxy_user.name
}

output "cloudsql_connection_name" {
  description = "The Cloud SQL connection name being used"
  value       = local.connection_name
}

output "dns_connection_address" {
  description = "DNS address to connect to (requires domain ownership)"
  value       = "db.${var.dns_domain}"
}
