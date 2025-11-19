#!/bin/bash
# Script to grant database permissions to IAM user
# This should be run after Terraform apply completes

set -e

echo "=== Granting Database Permissions to IAM User ==="

# Get the postgres password from Terraform output
cd "$(dirname "$0")/../infra"
POSTGRES_PASSWORD=$(terraform output -raw postgres_password)
DB_USER=$(terraform output -raw db_user)
PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || echo "$1")

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID not found. Please pass it as first argument."
  echo "Usage: $0 <project-id>"
  exit 1
fi

echo "Project ID: $PROJECT_ID"
echo "DB User: $DB_USER"

# Create a temporary pod manifest
cat > /tmp/grant-permissions-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: grant-permissions-pod
  namespace: jhub
spec:
  serviceAccountName: jupyter-user-sa
  restartPolicy: Never
  containers:
  - name: psql-container
    image: postgres:15
    command: ["/bin/sh", "-c"]
    args:
      - |
        sleep 5
        PGPASSWORD='${POSTGRES_PASSWORD}' psql -h 127.0.0.1 -p 5432 -U postgres -d jupyterhub_db <<'EOSQL'
        GRANT ALL PRIVILEGES ON DATABASE jupyterhub_db TO "${DB_USER}";
        GRANT ALL PRIVILEGES ON SCHEMA public TO "${DB_USER}";
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "${DB_USER}";
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "${DB_USER}";
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO "${DB_USER}";
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO "${DB_USER}";
EOSQL
  - name: cloud-sql-proxy
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.14.2
    args:
      - "--private-ip"
      - "--structured-logs"
      - "--port=5432"
      - "${PROJECT_ID}:us-central1:jupyterhub-db-instance"
    securityContext:
      runAsNonRoot: true
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
EOF

echo "Applying grant permissions pod..."
kubectl apply -f /tmp/grant-permissions-pod.yaml

echo "Waiting for pod to complete..."
kubectl wait --for=condition=Ready pod/grant-permissions-pod -n jhub --timeout=60s || true
sleep 10

echo "Checking logs..."
kubectl logs grant-permissions-pod -n jhub -c psql-container || echo "Pod may still be starting..."

echo "Waiting for completion..."
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/grant-permissions-pod -n jhub --timeout=60s || true

echo "Final logs:"
kubectl logs grant-permissions-pod -n jhub -c psql-container

echo "Cleaning up..."
kubectl delete pod grant-permissions-pod -n jhub

echo "=== Permissions granted successfully! ==="
