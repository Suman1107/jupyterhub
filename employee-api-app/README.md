# Employee API Application

A production-ready employee management web application with full Kubernetes deployment on GKE.

## Architecture Overview

- **Frontend**: HTML/JavaScript SPA
- **Backend**: Python FastAPI
- **Database**: SQLite with persistent volume
- **Container**: Docker
- **Orchestration**: Kubernetes (GKE)
- **CI/CD**: Google Cloud Build
- **Infrastructure**: Terraform

## Project Structure

```
employee-api-app/
├── app/
│   ├── main.py              # FastAPI application
│   ├── database.py          # Database connection and models
│   ├── models.py            # Pydantic models
│   └── requirements.txt     # Python dependencies
├── static/
│   ├── index.html           # Frontend UI
│   └── js/
│       └── app.js           # Frontend JavaScript
├── k8s/
│   ├── namespace.yaml       # Kubernetes namespace
│   ├── deployment.yaml      # Application deployment
│   ├── service.yaml         # ClusterIP service
│   ├── ingress.yaml         # NGINX ingress
│   ├── pvc.yaml             # Persistent volume claim
│   └── hpa.yaml             # Horizontal Pod Autoscaler
├── terraform/
│   ├── main.tf              # Main Terraform configuration
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   ├── provider.tf          # Provider configuration
│   ├── kubernetes.tf        # Kubernetes resources
│   ├── artifact_registry.tf # Artifact Registry setup
│   └── cloudbuild.tf        # Cloud Build trigger
├── Dockerfile               # Container image definition
├── .dockerignore            # Docker ignore patterns
├── cloudbuild.yaml          # CI/CD pipeline
└── README.md                # This file
```

## Quick Start

### Prerequisites

- Docker installed locally
- `gcloud` CLI configured
- `kubectl` configured for your GKE cluster
- Terraform >= 1.0
- Access to GCP project: `suman-110797`

### 1. Run Locally with Docker

```bash
# Build the image
docker build -t employee-api:local .

# Run the container
docker run -p 8080:8080 -v $(pwd)/data:/app/data employee-api:local

# Access the application
open http://localhost:8080
```

### 2. Build and Push Image to Artifact Registry

```bash
# Set variables
export PROJECT_ID=suman-110797
export REGION=us-central1
export REPO_NAME=employee-api
export IMAGE_NAME=employee-api
export IMAGE_TAG=v1.0.0

# Configure Docker for Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Build the image
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_TAG} .

# Push to Artifact Registry
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_TAG}
```

### 3. Deploy with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster"

# Apply the configuration
terraform apply \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster"
```

### 4. Deploy with Cloud Build (CI/CD)

```bash
# Submit a build manually
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_IMAGE_TAG=v1.0.0 \
  --project=suman-110797

# Or set up automatic builds from GitHub
# (Terraform will create the trigger)
```

## API Documentation

### Base URL

After deployment, access via Ingress:
```
http://<INGRESS_IP>/api
```

### Endpoints

#### GET /api/employees
Returns list of all employees.

**Response:**
```json
{
  "employees": [
    {
      "name": "John Doe",
      "email": "john.doe@example.com",
      "created_at": "2025-11-21T09:00:00Z"
    }
  ]
}
```

#### POST /api/employees
Add or update an employee.

**Request:**
```json
{
  "name": "Jane Smith",
  "email": "jane.smith@example.com"
}
```

**Response:**
```json
{
  "message": "Employee added successfully",
  "employee": {
    "name": "Jane Smith",
    "email": "jane.smith@example.com",
    "created_at": "2025-11-21T09:05:00Z"
  }
}
```

#### DELETE /api/employees/{email}
Remove an employee by email.

**Response:**
```json
{
  "message": "Employee deleted successfully"
}
```

#### GET /health
Health check endpoint (used by Kubernetes probes).

**Response:**
```json
{
  "status": "healthy"
}
```

## Accessing the UI

### Local Development
```
http://localhost:8080
```

### Production (via Ingress)

1. Get the Ingress IP:
```bash
kubectl get ingress -n employee-api employee-api-ingress
```

2. Access the UI:
```
http://<INGRESS_IP>
```

3. (Optional) Set up DNS:
```bash
# Add A record pointing to Ingress IP
# Example: employee-api.yourdomain.com -> <INGRESS_IP>
```

## Integration with Cloud Function

This API can be integrated with your Google Group sync automation Cloud Function.

### Example Integration

```python
import requests
import functions_framework
from google.cloud import secretmanager

@functions_framework.http
def sync_employees_to_groups(request):
    """Sync employees from API to Google Groups"""
    
    # Get employee API endpoint
    api_url = "http://employee-api.employee-api.svc.cluster.local/api/employees"
    
    # Fetch employees
    response = requests.get(api_url)
    employees = response.json()["employees"]
    
    # Sync to Google Groups
    for employee in employees:
        email = employee["email"]
        # Add to Google Group using Admin SDK
        # ... your existing sync logic
    
    return {"status": "success", "synced": len(employees)}
```

### Service-to-Service Communication

If your Cloud Function runs in the same GKE cluster:
```python
# Use internal service DNS
API_URL = "http://employee-api.employee-api.svc.cluster.local/api/employees"
```

If your Cloud Function runs outside the cluster:
```python
# Use Ingress URL
API_URL = "http://<INGRESS_IP>/api/employees"
```

## Kubernetes Resources

### Deployment
- **Replicas**: 2 (minimum for HA)
- **Resources**: 
  - Requests: 100m CPU, 128Mi memory
  - Limits: 500m CPU, 512Mi memory
- **Probes**: Liveness and readiness checks on `/health`
- **Security**: Non-root user, read-only root filesystem

### Service
- **Type**: ClusterIP
- **Port**: 80 → 8080

### Ingress
- **Class**: nginx
- **Path**: `/` (all traffic)

### HPA
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Target CPU**: 70%

### PVC
- **Storage**: 1Gi
- **Access Mode**: ReadWriteOnce
- **Purpose**: SQLite database persistence

## Monitoring and Troubleshooting

### View Logs
```bash
# Get pod logs
kubectl logs -n employee-api -l app=employee-api --tail=100 -f

# View all pods
kubectl get pods -n employee-api

# Describe deployment
kubectl describe deployment -n employee-api employee-api
```

### Check Health
```bash
# Port-forward to test locally
kubectl port-forward -n employee-api svc/employee-api 8080:80

# Test health endpoint
curl http://localhost:8080/health
```

### Scale Manually
```bash
# Scale to 5 replicas
kubectl scale deployment -n employee-api employee-api --replicas=5
```

### Database Access
```bash
# Access SQLite database in pod
kubectl exec -it -n employee-api <pod-name> -- sqlite3 /app/data/employees.db

# Run SQL query
sqlite> SELECT * FROM employees;
```

## Production Best Practices Implemented

✅ **Security**
- Non-root container user
- Read-only root filesystem
- Resource limits to prevent resource exhaustion
- CORS configured for frontend

✅ **Reliability**
- Liveness and readiness probes
- Multiple replicas for high availability
- Persistent volume for data durability
- Horizontal pod autoscaling

✅ **Observability**
- Structured logging
- Health check endpoints
- Kubernetes events and metrics

✅ **CI/CD**
- Automated builds with Cloud Build
- Versioned image tags
- Idempotent deployments

✅ **Infrastructure as Code**
- Complete Terraform configuration
- Modular and reusable
- State management ready

## Cleanup

### Remove Kubernetes Resources
```bash
cd terraform
terraform destroy \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster"
```

### Or manually
```bash
kubectl delete namespace employee-api
```

## Environment Variables

The application supports the following environment variables:

- `DATABASE_PATH`: Path to SQLite database (default: `/app/data/employees.db`)
- `PORT`: Application port (default: `8080`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

## Support

For issues or questions:
1. Check application logs: `kubectl logs -n employee-api -l app=employee-api`
2. Verify Ingress: `kubectl get ingress -n employee-api`
3. Check pod status: `kubectl get pods -n employee-api`

## License

MIT License
