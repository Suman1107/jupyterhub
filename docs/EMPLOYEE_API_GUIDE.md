# Employee API with KMS Token Encryption

## Overview

This is a complete solution for secure API access using Google Cloud KMS for token encryption.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Complete Flow                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Employee API (FastAPI on GKE)                           │
│     - User signup/login                                     │
│     - Employee CRUD operations                              │
│     - PostgreSQL backend (Cloud SQL)                        │
│     - API key generation                                    │
│                                                             │
│  2. Token Generator (Cloud Function)                        │
│     - Takes: api_id, api_secret, user_id, expiry           │
│     - Encrypts with KMS                                     │
│     - Returns: encrypted token                              │
│                                                             │
│  3. API Consumer (JupyterHub Notebook)                      │
│     - Takes: encrypted token                                │
│     - Decrypts with KMS                                     │
│     - Calls Employee API                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Employee API (FastAPI)

**Location:** `employee-api/`

**Features:**
- User authentication (signup/login)
- Employee management (CRUD)
- API key generation
- PostgreSQL backend with Cloud SQL Proxy
- JWT and API key authentication

**Endpoints:**
- `POST /auth/signup` - Create new user
- `POST /auth/login` - Login and get JWT
- `POST /auth/api-key` - Generate API credentials
- `GET /api/employees` - List all employees
- `POST /api/employees` - Create employee
- `GET /api/employees/{id}` - Get employee by ID

### 2. Token Generator (Cloud Function)

**Location:** `cloud-functions/token-generator/`

**Purpose:** Encrypt API credentials using Google Cloud KMS

**Input:**
```json
{
  "api_id": "your-api-id",
  "api_secret": "your-api-secret",
  "user_id": "jupyterhub-username",
  "expiry_hours": 24
}
```

**Output:**
```json
{
  "token": "base64-encrypted-token",
  "expires_at": "2025-11-20T12:00:00",
  "user_id": "jupyterhub-username"
}
```

### 3. API Consumer (JupyterHub Library)

**Location:** `scripts/api_consumer.py`

**Purpose:** Decrypt tokens and access the Employee API from notebooks

**Usage:**
```python
from api_consumer import SecureAPIClient

# Your encrypted token
token = "YOUR_ENCRYPTED_TOKEN_HERE"

# Create client (automatically decrypts)
client = SecureAPIClient(token)

# Fetch employees
employees = client.get_employees()
```

## Deployment

### Prerequisites

1. GCP Project with billing enabled
2. APIs enabled:
   - Cloud KMS
   - Cloud Functions
   - Container Registry
   - GKE

### Step 1: Deploy Infrastructure (KMS)

```bash
cd infra
terraform init
terraform apply -var="project_id=suman-110797"
```

This creates:
- KMS Key Ring: `jupyterhub-keyring`
- Crypto Key: `auth-token-key`
- IAM bindings for encryption/decryption

### Step 2: Deploy Employee API

```bash
./employee-api/deploy.sh suman-110797 us-central1
```

This will:
1. Build Docker image
2. Push to GCR
3. Deploy to GKE
4. Create Kubernetes service

### Step 3: Deploy Token Generator

```bash
./cloud-functions/deploy.sh suman-110797 us-central1
```

This deploys the Cloud Function and returns the URL.

## Usage Guide

### For Administrators

#### 1. Create a User Account

```bash
curl -X POST http://localhost:8000/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "secure_password",
    "full_name": "John Doe"
  }'
```

#### 2. Generate API Credentials

```bash
curl -X POST http://localhost:8000/auth/api-key \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "john_doe"
  }'
```

Response:
```json
{
  "api_id": "abc123...",
  "api_secret": "xyz789...",
  "created_at": "2025-11-19T12:00:00",
  "expires_at": "2026-11-19T12:00:00"
}
```

#### 3. Generate Encrypted Token

```bash
curl -X POST https://FUNCTION_URL/generate_token \
  -H 'Content-Type: application/json' \
  -d '{
    "api_id": "abc123...",
    "api_secret": "xyz789...",
    "user_id": "suman",
    "expiry_hours": 24
  }'
```

Response:
```json
{
  "token": "CiQAZL...encrypted...base64...",
  "expires_at": "2025-11-20T12:00:00",
  "user_id": "suman"
}
```

### For JupyterHub Users

#### 1. Install Dependencies

```python
!pip install google-cloud-kms requests
```

#### 2. Use the API Consumer

```python
from api_consumer import SecureAPIClient, test_api_access

# Your encrypted token (provided by admin)
token = "CiQAZL...encrypted...base64..."

# Test access
test_api_access(token)

# Or create client directly
client = SecureAPIClient(token)

# Fetch all employees
employees = client.get_employees()
for emp in employees:
    print(f"{emp['first_name']} {emp['last_name']} - {emp['department']}")

# Get specific employee
emp = client.get_employee(1)
print(emp)

# Create new employee
new_emp = client.create_employee({
    "first_name": "Jane",
    "last_name": "Smith",
    "email": "jane.smith@example.com",
    "department": "Data Science",
    "position": "Data Analyst",
    "salary": 80000
})
```

## Security Features

### 1. KMS Encryption
- API credentials are encrypted using Google-managed keys
- Only authorized service accounts can decrypt
- Keys automatically rotated every 90 days

### 2. Identity Binding
- Token includes `user_id` (JupyterHub username)
- Can be validated against actual pod identity
- Prevents token sharing between users

### 3. Expiry
- Tokens have configurable expiration
- Default: 24 hours
- Expired tokens cannot be decrypted

### 4. Audit Logging
- All KMS operations logged to Cloud Audit Logs
- Track who decrypted tokens and when
- API access logged in application logs

## Monitoring

### View KMS Operations

```bash
gcloud logging read \
  'resource.type="cloudkms.googleapis.com/CryptoKey"
   AND protoPayload.methodName=~"Decrypt|Encrypt"' \
  --limit=50 \
  --format="table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName)"
```

### View API Access

```bash
kubectl logs -n jhub -l app=employee-api --tail=100
```

## Troubleshooting

### Token Decryption Fails

**Error:** `Permission denied`

**Solution:** Verify service account has `cloudkms.cryptoKeyDecrypter` role:
```bash
gcloud kms keys get-iam-policy auth-token-key \
  --keyring=jupyterhub-keyring \
  --location=global \
  --project=suman-110797
```

### API Returns 401

**Error:** `Invalid API key`

**Solution:** 
1. Verify token hasn't expired
2. Check API credentials are correct
3. Ensure API is accessible from JupyterHub pods

### Employee API Not Accessible

**Error:** `Connection refused`

**Solution:**
```bash
# Check if pods are running
kubectl get pods -n jhub -l app=employee-api

# Check service
kubectl get svc -n jhub employee-api

# Port forward for testing
kubectl port-forward -n jhub svc/employee-api 8000:80
```

## Cost Estimate

| Component | Monthly Cost |
|-----------|-------------|
| Cloud KMS | ~$0.06 (1 key) |
| Cloud Function | ~$0.40 (1M invocations free tier) |
| GKE (API pods) | Included in existing cluster |
| Cloud SQL | Included in existing instance |
| **Total** | **~$0.50/month** |

## Next Steps

1. ✅ Deploy infrastructure (KMS)
2. ✅ Deploy Employee API
3. ✅ Deploy Token Generator
4. ⏳ Create test users and employees
5. ⏳ Generate encrypted tokens
6. ⏳ Test from JupyterHub notebooks
7. ⏳ Set up monitoring and alerts

## Support

For issues or questions:
- Check logs: `kubectl logs -n jhub -l app=employee-api`
- View KMS audit logs
- Contact DevOps team
