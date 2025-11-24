# Secret Manager secrets for OAuth2 client credentials

resource "google_secret_manager_secret" "client_id" {
  secret_id = "employee-api-client-id"
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "client_id_version" {
  secret      = google_secret_manager_secret.client_id.id
  secret_data = var.oauth_client_id
}

resource "google_secret_manager_secret" "client_secret" {
  secret_id = "employee-api-client-secret"
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "client_secret_version" {
  secret      = google_secret_manager_secret.client_secret.id
  secret_data = var.oauth_client_secret
}
