#!/bin/bash
# Deploy Employee API to GKE

set -e

PROJECT_ID=${1:-suman-110797}
REGION=${2:-us-central1}

echo "🚀 Deploying Employee API"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Step 1: Build and push Docker image
echo "📦 Building Docker image..."
cd employee-api
docker build -t gcr.io/$PROJECT_ID/employee-api:latest .

echo "📤 Pushing to Google Container Registry..."
docker push gcr.io/$PROJECT_ID/employee-api:latest

# Step 2: Deploy to Kubernetes
echo "☸️  Deploying to Kubernetes..."
kubectl apply -f k8s/deployment.yaml

# Step 3: Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/employee-api -n jhub

# Step 4: Get service info
echo ""
echo "✅ Deployment complete!"
echo ""
echo "Service URL (internal): http://employee-api.jhub.svc.cluster.local"
echo ""
echo "To test locally, run:"
echo "  kubectl port-forward -n jhub svc/employee-api 8000:80"
echo ""
echo "Then access: http://localhost:8000"
