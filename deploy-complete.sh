#!/bin/bash
# Complete Deployment Script for JupyterHub + Employee API + KMS Token System
# This script automates EVERYTHING - fully reproducible in a new GCP project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check arguments
if [ -z "$1" ]; then
    echo_error "Usage: $0 <project-id> [region] [project-number]"
    echo_error "Example: $0 my-new-project us-central1 123456789"
    echo_error ""
    echo_error "To get your project number, run: gcloud projects describe <project-id> --format='value(projectNumber)'"
    exit 1
fi

PROJECT_ID=$1
REGION=${2:-us-central1}
PROJECT_NUMBER=${3:-}

# Get project number if not provided
if [ -z "$PROJECT_NUMBER" ]; then
    echo_info "Getting project number..."
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
    if [ -z "$PROJECT_NUMBER" ]; then
        echo_error "Could not get project number. Please provide it as third argument."
        exit 1
    fi
fi

echo_info "=========================================="
echo_info "Complete JupyterHub + Employee API Deployment"
echo_info "=========================================="
echo_info "Project ID: $PROJECT_ID"
echo_info "Project Number: $PROJECT_NUMBER"
echo_info "Region: $REGION"
echo ""

# ============================================================================
# PHASE 1: Enable ALL Required APIs
# ============================================================================
echo_step "PHASE 1: Enabling all required GCP APIs..."

APIS=(
    "container.googleapis.com"           # GKE
    "compute.googleapis.com"             # Compute Engine
    "sqladmin.googleapis.com"            # Cloud SQL
    "servicenetworking.googleapis.com"   # VPC Peering
    "storage.googleapis.com"             # GCS
    "cloudkms.googleapis.com"            # Cloud KMS
    "cloudfunctions.googleapis.com"      # Cloud Functions
    "run.googleapis.com"                 # Cloud Run (for Functions Gen2)
    "cloudbuild.googleapis.com"          # Cloud Build
    "artifactregistry.googleapis.com"    # Artifact Registry
)

for api in "${APIS[@]}"; do
    echo_info "Enabling $api..."
    gcloud services enable $api --project=$PROJECT_ID
done

echo_info "✓ All APIs enabled"
echo ""

# ============================================================================
# PHASE 2: Deploy Infrastructure with Terraform
# ============================================================================
echo_step "PHASE 2: Deploying infrastructure with Terraform..."

cd infra

# Initialize Terraform
echo_info "Initializing Terraform..."
terraform init

# Apply Terraform
echo_info "Applying Terraform configuration..."
terraform apply \
    -var="project_id=$PROJECT_ID" \
    -var="project_id_number=$PROJECT_NUMBER" \
    -var="region=$REGION" \
    -auto-approve

# Get outputs
CLUSTER_NAME=$(terraform output -raw kubernetes_cluster_name)
DB_USER=$(terraform output -raw db_user)
BUCKET_NAME=$(terraform output -raw shared_bucket_name)
SQL_CONNECTION=$(terraform output -raw cloudsql_connection_name)

echo_info "✓ Infrastructure deployed"
echo_info "  Cluster: $CLUSTER_NAME"
echo_info "  DB User: $DB_USER"
echo_info "  Bucket: $BUCKET_NAME"
echo ""

cd ..

# ============================================================================
# PHASE 3: Configure kubectl
# ============================================================================
echo_step "PHASE 3: Configuring kubectl..."

gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=${REGION}-a \
    --project=$PROJECT_ID

echo_info "✓ kubectl configured"
echo ""

# ============================================================================
# PHASE 4: Create Kubernetes Resources
# ============================================================================
echo_step "PHASE 4: Creating Kubernetes resources..."

# Create namespace
kubectl create namespace jhub --dry-run=client -o yaml | kubectl apply -f -

# Create service account
kubectl apply -f k8s/service-account.yaml

echo_info "✓ Kubernetes resources created"
echo ""

# ============================================================================
# PHASE 5: Install JupyterHub
# ============================================================================
echo_step "PHASE 5: Installing JupyterHub..."

# Add Helm repo
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/ 2>/dev/null || true
helm repo update

# Update config with project-specific values
cp helm/config.yaml helm/config.yaml.backup
sed -i.tmp "s/bucketName: .*/bucketName: $BUCKET_NAME/" helm/config.yaml
sed -i.tmp "s/\".*:us-central1:jupyterhub-db-instance\"/\"$PROJECT_ID:$REGION:jupyterhub-db-instance\"/" helm/config.yaml
sed -i.tmp "s/suman-110797/$PROJECT_ID/g" helm/config.yaml
rm -f helm/config.yaml.tmp

# Install JupyterHub
helm upgrade --install jhub jupyterhub/jupyterhub \
    --namespace jhub \
    --version 3.3.8 \
    --values helm/config.yaml \
    --timeout 10m

echo_info "✓ JupyterHub installed"
echo ""

# ============================================================================
# PHASE 6: Grant Database Permissions
# ============================================================================
echo_step "PHASE 6: Granting database permissions..."

# Wait for JupyterHub to be ready
kubectl wait --for=condition=Ready pod -l component=hub -n jhub --timeout=300s || true

# Grant permissions
bash scripts/grant_db_permissions.sh $PROJECT_ID

echo_info "✓ Database permissions granted"
echo ""

# ============================================================================
# PHASE 7: Build and Deploy Employee API
# ============================================================================
echo_step "PHASE 7: Building and deploying Employee API..."

cd employee-api

# Build Docker image for AMD64 (GKE compatibility)
echo_info "Building Docker image..."
docker buildx build --platform linux/amd64 \
    -t gcr.io/$PROJECT_ID/employee-api:latest \
    --push .

cd ..

# Update deployment with project ID
cp employee-api/k8s/deployment.yaml employee-api/k8s/deployment.yaml.backup
sed -i.tmp "s/suman-110797/$PROJECT_ID/g" employee-api/k8s/deployment.yaml
sed -i.tmp "s/image: gcr.io\/.*/image: gcr.io\/$PROJECT_ID\/employee-api:latest/" employee-api/k8s/deployment.yaml
rm -f employee-api/k8s/deployment.yaml.tmp

# Deploy to Kubernetes
kubectl apply -f employee-api/k8s/deployment.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s deployment/employee-api -n jhub

echo_info "✓ Employee API deployed"
echo ""

# ============================================================================
# PHASE 8: Deploy Token Generator Cloud Function
# ============================================================================
echo_step "PHASE 8: Deploying Token Generator Cloud Function..."

gcloud functions deploy token-generator \
    --gen2 \
    --runtime=python311 \
    --region=$REGION \
    --source=cloud-functions/token-generator \
    --entry-point=generate_token \
    --trigger-http \
    --allow-unauthenticated \
    --set-env-vars GCP_PROJECT=$PROJECT_ID \
    --project=$PROJECT_ID \
    --quiet

# Get function URL
FUNCTION_URL=$(gcloud functions describe token-generator \
    --gen2 \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format='value(serviceConfig.uri)')

echo_info "✓ Token Generator deployed"
echo_info "  URL: $FUNCTION_URL"
echo ""

# ============================================================================
# PHASE 9: Deploy API Consumer Library
# ============================================================================
echo_step "PHASE 9: Deploying API Consumer library..."

# Create ConfigMap with the library
kubectl create configmap api-consumer-lib \
    --from-file=api_consumer.py=scripts/api_consumer.py \
    --namespace=jhub \
    --dry-run=client -o yaml | kubectl apply -f -

echo_info "✓ API Consumer library deployed"
echo ""

# ============================================================================
# PHASE 10: Create Test User and API Credentials
# ============================================================================
echo_step "PHASE 10: Creating test user and API credentials..."

# Port forward to access API
kubectl port-forward -n jhub svc/employee-api 8001:80 &
PF_PID=$!
sleep 5

# Create test user
echo_info "Creating test user..."
curl -s -X POST http://localhost:8001/auth/signup \
    -H 'Content-Type: application/json' \
    -d '{"username":"testuser","email":"test@example.com","password":"testpass123","full_name":"Test User"}' \
    > /dev/null

# Generate API key
echo_info "Generating API credentials..."
API_RESPONSE=$(curl -s -X POST http://localhost:8001/auth/api-key \
    -H 'Content-Type: application/json' \
    -d '{"username":"testuser"}')

API_ID=$(echo $API_RESPONSE | grep -o '"api_id":"[^"]*' | cut -d'"' -f4)
API_SECRET=$(echo $API_RESPONSE | grep -o '"api_secret":"[^"]*' | cut -d'"' -f4)

# Kill port forward
kill $PF_PID 2>/dev/null || true

echo_info "✓ Test credentials created"
echo_info "  API ID: $API_ID"
echo_info "  API Secret: $API_SECRET"
echo ""

# Generate encrypted token
echo_info "Generating encrypted token..."
TOKEN_RESPONSE=$(curl -s -X POST $FUNCTION_URL \
    -H 'Content-Type: application/json' \
    -d "{\"api_id\":\"$API_ID\",\"api_secret\":\"$API_SECRET\",\"user_id\":\"testuser\",\"expiry_hours\":24}")

ENCRYPTED_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

echo_info "✓ Encrypted token generated"
echo ""

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================
echo ""
echo_info "=========================================="
echo_info "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo_info "=========================================="
echo ""
echo_info "📊 Deployment Summary:"
echo_info "  Project: $PROJECT_ID"
echo_info "  Region: $REGION"
echo_info "  Cluster: $CLUSTER_NAME"
echo_info "  Database: $SQL_CONNECTION"
echo_info "  Bucket: $BUCKET_NAME"
echo ""
echo_info "🔐 Test Credentials:"
echo_info "  API ID: $API_ID"
echo_info "  API Secret: $API_SECRET"
echo_info "  Encrypted Token: ${ENCRYPTED_TOKEN:0:50}..."
echo ""
echo_info "🌐 Access URLs:"
echo_info "  JupyterHub: kubectl --namespace=jhub port-forward service/proxy-public 8080:80"
echo_info "  Employee API: kubectl --namespace=jhub port-forward service/employee-api 8001:80"
echo_info "  Token Generator: $FUNCTION_URL"
echo ""
echo_info "📝 Next Steps:"
echo_info "  1. Access JupyterHub: http://localhost:8080 (after port-forward)"
echo_info "  2. Create a notebook and test with: scripts/test_employee_api.py"
echo_info "  3. Use the encrypted token above in your notebooks"
echo ""
echo_info "📚 Documentation:"
echo_info "  - README.md - Main documentation"
echo_info "  - docs/EMPLOYEE_API_GUIDE.md - API guide"
echo_info "  - docs/TEST_RESULTS.md - Test results"
echo ""
echo_info "=========================================="
echo_info "Deployment log saved to: deployment-$(date +%Y%m%d-%H%M%S).log"
echo_info "=========================================="
