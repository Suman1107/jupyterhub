#!/bin/bash
# Quick deployment script for Employee API

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-suman-110797}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-jupyterhub-cluster}"
CLUSTER_ZONE="${CLUSTER_ZONE:-us-central1-a}"
IMAGE_TAG="${IMAGE_TAG:-v1.0.0}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Employee API Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Zone: $CLUSTER_ZONE"
echo "Image Tag: $IMAGE_TAG"
echo ""

# Function to print step
print_step() {
    echo -e "${YELLOW}>>> $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not found. Please install it first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install it first."
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "terraform not found. Please install it first."
    exit 1
fi

print_step "Setting GCP project..."
gcloud config set project $PROJECT_ID
print_success "Project set to $PROJECT_ID"

print_step "Getting GKE credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$CLUSTER_ZONE
print_success "GKE credentials configured"

print_step "Initializing Terraform..."
cd terraform
terraform init
print_success "Terraform initialized"

print_step "Planning Terraform deployment..."
terraform plan \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -var="cluster_name=$CLUSTER_NAME" \
    -var="cluster_location=$CLUSTER_ZONE" \
    -var="image_tag=$IMAGE_TAG" \
    -out=tfplan
print_success "Terraform plan created"

echo ""
echo -e "${YELLOW}Review the plan above. Do you want to apply? (yes/no)${NC}"
read -r response

if [[ "$response" != "yes" ]]; then
    print_error "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

print_step "Applying Terraform configuration..."
terraform apply tfplan
rm -f tfplan
print_success "Terraform applied successfully"

cd ..

print_step "Building and pushing Docker image..."
gcloud builds submit \
    --config=cloudbuild.yaml \
    --substitutions=_IMAGE_TAG=$IMAGE_TAG \
    --project=$PROJECT_ID

print_success "Build and deployment complete!"

echo ""
print_step "Getting deployment status..."
kubectl get all -n employee-api

echo ""
print_step "Getting Ingress IP..."
kubectl get ingress -n employee-api employee-api-ingress

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "To access the application:"
echo "1. Get the Ingress IP: kubectl get ingress -n employee-api"
echo "2. Open http://<INGRESS_IP> in your browser"
echo ""
echo "To view logs:"
echo "kubectl logs -n employee-api -l app=employee-api --tail=100 -f"
echo ""
echo "To scale:"
echo "kubectl scale deployment -n employee-api employee-api --replicas=5"
echo ""
