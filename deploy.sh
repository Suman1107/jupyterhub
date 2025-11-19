#!/bin/bash
# Complete deployment script for JupyterHub with Cloud SQL PostgreSQL
# This script automates the entire deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PROJECT_ID is provided
if [ -z "$1" ]; then
    echo_error "Usage: $0 <project-id>"
    echo_error "Example: $0 my-gcp-project"
    exit 1
fi

PROJECT_ID=$1
REGION=${2:-us-central1}

echo_info "Starting deployment for project: $PROJECT_ID"
echo_info "Region: $REGION"

# Step 1: Enable required APIs
echo_info "Step 1: Enabling required GCP APIs..."
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    servicenetworking.googleapis.com \
    storage.googleapis.com \
    --project=$PROJECT_ID

echo_info "APIs enabled successfully!"

# Step 2: Deploy infrastructure with Terraform
echo_info "Step 2: Deploying infrastructure with Terraform..."
cd infra

terraform init

terraform apply \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -auto-approve

echo_info "Infrastructure deployed successfully!"

# Get outputs
CLUSTER_NAME=$(terraform output -raw kubernetes_cluster_name)
DB_USER=$(terraform output -raw db_user)
BUCKET_NAME=$(terraform output -raw shared_bucket_name)

cd ..

# Step 3: Get GKE credentials
echo_info "Step 3: Getting GKE cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=${REGION}-a \
    --project=$PROJECT_ID

echo_info "Cluster credentials configured!"

# Step 4: Create Kubernetes namespace
echo_info "Step 4: Creating Kubernetes namespace..."
kubectl create namespace jhub --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Create Kubernetes service account with Workload Identity
echo_info "Step 5: Creating Kubernetes service account..."
kubectl apply -f k8s/service-account.yaml

# Step 6: Install JupyterHub with Helm
echo_info "Step 6: Installing JupyterHub..."

# Add Helm repo if not already added
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/ 2>/dev/null || true
helm repo update

# Update config.yaml with correct bucket name
sed -i.bak "s/bucketName: .*/bucketName: $BUCKET_NAME/" helm/config.yaml

# Update config.yaml with correct project ID in Cloud SQL Proxy
sed -i.bak "s/\".*:us-central1:jupyterhub-db-instance\"/\"$PROJECT_ID:us-central1:jupyterhub-db-instance\"/" helm/config.yaml

helm upgrade --install jhub jupyterhub/jupyterhub \
    --namespace jhub \
    --version 3.3.8 \
    --values helm/config.yaml \
    --timeout 10m

echo_info "JupyterHub installed successfully!"

# Step 7: Wait for JupyterHub to be ready
echo_info "Step 7: Waiting for JupyterHub pods to be ready..."
kubectl wait --for=condition=Ready pod -l component=hub -n jhub --timeout=300s

# Step 8: Grant database permissions
echo_info "Step 8: Granting database permissions to IAM user..."
bash scripts/grant_db_permissions.sh $PROJECT_ID

echo_info "Database permissions granted!"

# Step 9: Display access information
echo ""
echo_info "=========================================="
echo_info "Deployment completed successfully!"
echo_info "=========================================="
echo ""
echo_info "To access JupyterHub, run:"
echo_info "  kubectl --namespace=jhub port-forward service/proxy-public 8080:80"
echo ""
echo_info "Then open: http://localhost:8080"
echo ""
echo_info "Database details:"
echo_info "  Database: jupyterhub_db"
echo_info "  IAM User: $DB_USER"
echo_info "  Connection: localhost:5432 (via Cloud SQL Proxy sidecar)"
echo ""
echo_info "To test the database connection, create a JupyterHub user and run:"
echo_info "  scripts/jupyterhub_db_test.py"
echo ""
echo_info "=========================================="
