#!/bin/bash
# Cleanup script to destroy all resources

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

echo_warn "=========================================="
echo_warn "WARNING: This will destroy all resources!"
echo_warn "Project: $PROJECT_ID"
echo_warn "Region: $REGION"
echo_warn "=========================================="
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo_info "Cleanup cancelled."
    exit 0
fi

# Step 1: Uninstall JupyterHub
echo_info "Step 1: Uninstalling JupyterHub..."
helm uninstall jhub --namespace jhub 2>/dev/null || echo_warn "JupyterHub not found or already uninstalled"

# Step 2: Delete namespace (this will clean up PVCs)
echo_info "Step 2: Deleting Kubernetes namespace..."
kubectl delete namespace jhub --timeout=120s 2>/dev/null || echo_warn "Namespace not found or already deleted"

# Step 3: Destroy infrastructure with Terraform
echo_info "Step 3: Destroying infrastructure with Terraform..."
cd infra

terraform destroy \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -auto-approve

cd ..

echo_info "=========================================="
echo_info "Cleanup completed successfully!"
echo_info "=========================================="
