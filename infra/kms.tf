# Enable Cloud KMS API
resource "google_project_service" "kms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Functions API
resource "google_project_service" "cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Run API (required for Cloud Functions Gen2)
resource "google_project_service" "run" {
  project = var.project_id
  service = "run.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Build API (required for Cloud Functions)
resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Create Key Ring
resource "google_kms_key_ring" "key_ring" {
  name     = "jupyterhub-keyring"
  location = "global"
  project  = var.project_id
  depends_on = [google_project_service.kms]
}

# Create Crypto Key for Token Encryption
resource "google_kms_crypto_key" "token_key" {
  name            = "auth-token-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = false
  }
}

# Grant Decrypt permission to JupyterHub User SA
resource "google_kms_crypto_key_iam_member" "jupyter_decrypt" {
  crypto_key_id = google_kms_crypto_key.token_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.jupyter_user_sa.email}"
}

# Grant Encrypt/Decrypt permission to Compute Engine default SA (for Cloud Functions)
resource "google_kms_crypto_key_iam_member" "compute_encrypt_decrypt" {
  crypto_key_id = google_kms_crypto_key.token_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.project_id_number}-compute@developer.gserviceaccount.com"
}

# Output the key name for Cloud Function
output "kms_key_name" {
  value       = google_kms_crypto_key.token_key.id
  description = "The full KMS key name for token encryption"
}
