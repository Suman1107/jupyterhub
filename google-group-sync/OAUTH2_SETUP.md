# OAuth2 Authentication Setup Guide

This guide explains how to set up OAuth2 authentication for the Employee API and Google Group Sync integration.

## Overview

The system uses OAuth2 client credentials flow:
1. Client credentials (client_id and client_secret) are stored in Google Cloud Secret Manager
2. The Cloud Function retrieves these credentials from Secret Manager
3. The Cloud Function requests an access token from the Employee API
4. The access token is used to authenticate API requests

## Prerequisites

- Google Cloud Project with Secret Manager API enabled
- Employee API deployed and running
- Terraform installed

## Setup Steps

### 1. Generate Client Credentials

Generate a secure client ID and secret:

```bash
# Generate client ID (can be any unique identifier)
CLIENT_ID="employee-api-client-$(date +%s)"

# Generate secure client secret
CLIENT_SECRET=$(openssl rand -base64 32)

echo "Client ID: $CLIENT_ID"
echo "Client Secret: $CLIENT_SECRET"
```

**Important**: Save these values securely. You'll need them for the next steps.

### 2. Store Credentials in Secret Manager

```bash
# Set your project ID
export PROJECT_ID="your-project-id"

# Create secrets (Terraform will do this, but you can also do it manually)
gcloud secrets create employee-api-client-id \
    --project=$PROJECT_ID \
    --replication-policy="automatic"

gcloud secrets create employee-api-client-secret \
    --project=$PROJECT_ID \
    --replication-policy="automatic"

# Add secret versions with your credentials
echo -n "$CLIENT_ID" | gcloud secrets versions add employee-api-client-id \
    --project=$PROJECT_ID \
    --data-file=-

echo -n "$CLIENT_SECRET" | gcloud secrets versions add employee-api-client-secret \
    --project=$PROJECT_ID \
    --data-file=-
```

### 3. Update Employee API Environment Variables

The Employee API needs to know the GCP project ID to access Secret Manager:

```bash
# If deploying to Cloud Run
gcloud run services update employee-api \
    --update-env-vars GCP_PROJECT_ID=$PROJECT_ID \
    --region us-central1

# If deploying to Kubernetes, update the deployment YAML:
# env:
#   - name: GCP_PROJECT_ID
#     value: "your-project-id"
```

### 4. Deploy with Terraform

The Terraform configuration will:
- Enable Secret Manager API
- Grant the Cloud Function service account access to secrets
- Create the secrets (if they don't exist)

```bash
cd google-group-sync/terraform

terraform init
terraform apply \
    -var="project_id=$PROJECT_ID" \
    -var="employee_api_url=http://your-api-url" \
    -var="target_roles=roles/viewer,roles/storage.objectViewer"
```

### 5. Verify the Setup

Test the OAuth2 flow manually:

```bash
# Request a token
curl -X POST "http://your-api-url/api/token" \
    -H "Content-Type: application/json" \
    -d "{\"client_id\":\"$CLIENT_ID\",\"client_secret\":\"$CLIENT_SECRET\"}"

# Expected response:
# {
#   "access_token": "eyJ...",
#   "token_type": "bearer"
# }

# Use the token to access the API
TOKEN="<access_token_from_above>"

curl -H "Authorization: Bearer $TOKEN" \
    "http://your-api-url/api/employees"
```

### 6. Test the Cloud Function

Trigger the Cloud Function manually to verify it can authenticate:

```bash
gcloud functions call google-group-sync \
    --region us-central1 \
    --format json
```

## Security Best Practices

1. **Rotate Credentials Regularly**: Update the client secret periodically
2. **Use Short-Lived Tokens**: The default token expiration is 60 minutes
3. **Monitor Access**: Check Cloud Logging for authentication attempts
4. **Restrict Secret Access**: Only grant `secretmanager.secretAccessor` to necessary service accounts

## Troubleshooting

### "Invalid client credentials" error

- Verify the secrets exist in Secret Manager:
  ```bash
  gcloud secrets list --project=$PROJECT_ID
  ```
- Check the secret values match what the Employee API expects
- Ensure the Employee API has `GCP_PROJECT_ID` environment variable set

### "Permission denied" accessing secrets

- Verify the service account has the `roles/secretmanager.secretAccessor` role:
  ```bash
  gcloud projects get-iam-policy $PROJECT_ID \
      --flatten="bindings[].members" \
      --filter="bindings.members:group-sync-sa@*"
  ```

### Token expired errors

- Tokens expire after 60 minutes by default
- The Cloud Function requests a new token for each execution
- Check the `ACCESS_TOKEN_EXPIRE_MINUTES` setting in the Employee API

## API Endpoints

### Employee API

- `POST /api/token` - Get OAuth2 access token (no authentication required)
- `GET /api/employees` - List employees (requires Bearer token)
- `POST /api/employees` - Create employee (requires Bearer token)
- `DELETE /api/employees/{email}` - Delete employee (requires Bearer token)

### Token Request Format

```json
{
  "client_id": "your-client-id",
  "client_secret": "your-client-secret"
}
```

### Token Response Format

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

## Architecture

```
┌─────────────────┐
│ Cloud Scheduler │
└────────┬────────┘
         │ Triggers hourly
         ▼
┌─────────────────────┐
│  Cloud Function     │
│  (google-group-sync)│
└──────┬──────────────┘
       │
       │ 1. Get credentials
       ▼
┌─────────────────────┐
│  Secret Manager     │
│  - client_id        │
│  - client_secret    │
└─────────────────────┘
       │
       │ 2. Request token
       ▼
┌─────────────────────┐
│  Employee API       │
│  POST /api/token    │
└──────┬──────────────┘
       │
       │ 3. Return JWT token
       ▼
┌─────────────────────┐
│  Cloud Function     │
│  Uses token for API │
│  GET /api/employees │
└─────────────────────┘
```
