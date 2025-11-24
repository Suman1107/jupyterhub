# Secret Manager secrets for OAuth2 client credentials

resource "google_secret_manager_secret" "client_id" {
  secret_id = "employee-api-client-id"
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "client_secret" {
  secret_id = "employee-api-client-secret"
  
  replication {
    auto {}
  }
}

# Note: You need to manually add the secret versions using:
# gcloud secrets versions add employee-api-client-id --data-file=- <<< "your-client-id"
# gcloud secrets versions add employee-api-client-secret --data-file=- <<< "your-client-secret"
