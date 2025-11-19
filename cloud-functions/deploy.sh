#!/bin/bash
# Deploy Token Generator Cloud Function

set -e

PROJECT_ID=${1:-suman-110797}
REGION=${2:-us-central1}

echo "🚀 Deploying Token Generator Cloud Function"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

cd cloud-functions/token-generator

# Deploy Cloud Function
echo "📤 Deploying Cloud Function..."
gcloud functions deploy token-generator \
    --gen2 \
    --runtime=python311 \
    --region=$REGION \
    --source=. \
    --entry-point=generate_token \
    --trigger-http \
    --allow-unauthenticated \
    --set-env-vars GCP_PROJECT=$PROJECT_ID \
    --project=$PROJECT_ID

# Get function URL
FUNCTION_URL=$(gcloud functions describe token-generator \
    --gen2 \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format='value(serviceConfig.uri)')

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Function URL: $FUNCTION_URL"
echo ""
echo "Test with:"
echo "curl -X POST $FUNCTION_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"api_id\":\"test\",\"api_secret\":\"secret\",\"user_id\":\"suman\"}'"
