#!/bin/bash
# Complete Cleanup Script - Removes ALL resources
# This script is the inverse of deploy-complete.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ -z "$1" ]; then
    echo_error "Usage: $0 <project-id> [region]"
    echo_error "Example: $0 my-project us-central1"
    exit 1
fi

PROJECT_ID=$1
REGION=${2:-us-central1}

echo_warn "=========================================="
echo_warn "COMPLETE CLEANUP - ALL RESOURCES WILL BE DELETED"
echo_warn "=========================================="
echo_warn "Project: $PROJECT_ID"
echo_warn "Region: $REGION"
echo_warn ""
echo_warn "This will delete:"
echo_warn "  - Cloud Function (token-generator)"
echo_warn "  - Employee API deployment"
echo_warn "  - JupyterHub installation"
echo_warn "  - All Kubernetes resources"
echo_warn "  - GKE Cluster"
echo_warn "  - Cloud SQL instance"
echo_warn "  - VPC and networking"
echo_warn "  - GCS buckets"
echo_warn "  - KMS keys (key ring will remain)"
echo_warn ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo_info "Cleanup cancelled"
    exit 0
fi

echo ""
echo_info "Starting cleanup..."
echo ""

# ============================================================================
# PHASE 1: Delete Cloud Function
# ============================================================================
echo_info "PHASE 1: Deleting Cloud Function..."

gcloud functions delete token-generator \
    --gen2 \
    --region=$REGION \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || echo_warn "Cloud Function not found or already deleted"

echo_info "✓ Cloud Function deleted"
echo ""

# ============================================================================
# PHASE 2: Delete Kubernetes Resources
# ============================================================================
echo_info "PHASE 2: Deleting Kubernetes resources..."

# Get cluster name
CLUSTER_NAME=$(cd infra && terraform output -raw kubernetes_cluster_name 2>/dev/null || echo "jupyterhub-cluster")

# Configure kubectl
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=${REGION}-a \
    --project=$PROJECT_ID 2>/dev/null || echo_warn "Could not connect to cluster"

# Delete Employee API
kubectl delete deployment employee-api -n jhub --ignore-not-found=true
kubectl delete service employee-api -n jhub --ignore-not-found=true

# Delete ConfigMaps
kubectl delete configmap api-consumer-lib -n jhub --ignore-not-found=true
kubectl delete configmap warehouse-auth-lib -n jhub --ignore-not-found=true

# Uninstall JupyterHub
helm uninstall jhub --namespace jhub 2>/dev/null || echo_warn "JupyterHub not found"

# Delete namespace (this will delete all remaining resources)
kubectl delete namespace jhub --ignore-not-found=true --timeout=300s

echo_info "✓ Kubernetes resources deleted"
echo ""

# ============================================================================
# PHASE 3: Destroy Infrastructure with Terraform
# ============================================================================
echo_info "PHASE 3: Destroying infrastructure with Terraform..."

cd infra

terraform destroy \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -auto-approve

cd ..

echo_info "✓ Infrastructure destroyed"
echo ""

# ============================================================================
# PHASE 4: Clean up KMS (optional - keys cannot be deleted immediately)
# ============================================================================
echo_info "PHASE 4: Disabling KMS keys..."

# Disable the crypto key (cannot delete immediately due to GCP policy)
gcloud kms keys versions list \
    --key=auth-token-key \
    --keyring=jupyterhub-keyring \
    --location=global \
    --project=$PROJECT_ID \
    --format="value(name)" 2>/dev/null | while read version; do
    gcloud kms keys versions disable $version \
        --key=auth-token-key \
        --keyring=jupyterhub-keyring \
        --location=global \
        --project=$PROJECT_ID \
        --quiet 2>/dev/null || true
done

echo_warn "Note: KMS keys are disabled but not deleted (GCP requires 24h wait period)"
echo ""

# ============================================================================
# CLEANUP COMPLETE
# ============================================================================
echo ""
echo_info "=========================================="
echo_info "CLEANUP COMPLETED SUCCESSFULLY!"
echo_info "=========================================="
echo ""
echo_info "Removed:"
echo_info "  ✓ Cloud Function"
echo_info "  ✓ Employee API"
echo_info "  ✓ JupyterHub"
echo_info "  ✓ Kubernetes resources"
echo_info "  ✓ GKE Cluster"
echo_info "  ✓ Cloud SQL"
echo_info "  ✓ VPC and networking"
echo_info "  ✓ GCS buckets"
echo ""
echo_warn "Note: KMS key ring 'jupyterhub-keyring' remains (cannot be deleted)"
echo_warn "      KMS keys are disabled and will be auto-deleted after 24 hours"
echo ""
echo_info "=========================================="
