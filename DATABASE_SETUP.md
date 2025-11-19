# JupyterHub with Cloud SQL PostgreSQL Integration

This project demonstrates a complete JupyterHub deployment on GKE with Cloud SQL PostgreSQL database integration using IAM authentication.

## Architecture

### Infrastructure Components

1. **Private VPC** (`192.168.0.0/24`)
   - Custom VPC network for secure communication
   - Private subnet for GKE and Cloud SQL

2. **GKE Cluster**
   - Zonal cluster in `us-central1-a`
   - 2 nodes (`e2-standard-4`)
   - Workload Identity enabled
   - GCS FUSE CSI driver enabled

3. **Cloud SQL PostgreSQL**
   - PostgreSQL 15
   - `db-f1-micro` tier (minimum size)
   - Private IP only (no public IP)
   - IAM authentication enabled
   - Located in private VPC

4. **Service Account**
   - `jupyter-user-sa@suman-110797.iam.gserviceaccount.com`
   - Permissions:
     - `roles/cloudsql.client`
     - `roles/cloudsql.instanceUser`
     - `roles/storage.objectAdmin` (for GCS bucket)
   - Workload Identity binding to K8s SA

### JupyterHub Features

1. **Individual Persistent Disks**
   - Each user gets their own 10Gi persistent volume
   - Data persists across sessions

2. **Shared GCS Bucket**
   - Mounted at `/home/jovyan/shared`
   - Accessible to all users
   - Uses GCS FUSE CSI driver

3. **Cloud SQL Database Access**
   - Cloud SQL Auth Proxy sidecar container
   - IAM-based authentication (no passwords!)
   - Automatic token refresh
   - Connection available at `localhost:5432`

4. **Security**
   - Network policies enabled
   - Workload Identity for secure GCP access
   - Private database (no public IP)
   - Secure Boot enabled on nodes

## Database Connection Details

- **Host**: `127.0.0.1` (via Cloud SQL Proxy sidecar)
- **Port**: `5432`
- **Database**: `jupyterhub_db`
- **User**: `jupyter-user-sa@suman-110797.iam`
- **Authentication**: IAM (automatic via Cloud SQL Proxy)

## Testing Database Connection

### From a Test Pod

```bash
kubectl apply -f k8s/test-pod.yaml
kubectl logs test-db-pod -n jhub -c test-container
```

### From JupyterHub Notebook

1. Access JupyterHub at `http://localhost:8080` (with port-forward)
2. Create a new notebook
3. Copy the contents of `scripts/jupyterhub_db_test.py` into a cell
4. Run the cell

The script will:
- Install `psycopg2-binary`
- Connect to the database using IAM auth
- Create a test table
- Insert sample data
- Fetch and display recent records

## Deployment

### Prerequisites

```bash
# Set your project ID
export PROJECT_ID=suman-110797

# Authenticate
gcloud auth login
gcloud auth application-default login
```

### Deploy Infrastructure

```bash
cd infra
terraform init
terraform apply -var="project_id=$PROJECT_ID"
```

### Deploy JupyterHub

```bash
# Get cluster credentials
gcloud container clusters get-credentials jupyterhub-cluster \
  --zone us-central1-a \
  --project $PROJECT_ID

# Create namespace
kubectl create namespace jhub

# Create Kubernetes service account
kubectl apply -f k8s/service-account.yaml

# Install JupyterHub
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
helm upgrade --install jhub jupyterhub/jupyterhub \
  --namespace jhub \
  --version 3.3.8 \
  --values helm/config.yaml
```

### Access JupyterHub

```bash
kubectl --namespace=jhub port-forward service/proxy-public 8080:80
```

Then open `http://localhost:8080` in your browser.

## Configuration Files

- `infra/main.tf` - Terraform configuration for GCP resources
- `helm/config.yaml` - JupyterHub Helm values
- `k8s/service-account.yaml` - Kubernetes service account with Workload Identity
- `k8s/test-pod.yaml` - Test pod for database connectivity
- `scripts/jupyterhub_db_test.py` - User-friendly database test script

## Key Features Implemented

✅ Private VPC with CIDR `192.168.0.0/24`  
✅ Cloud SQL PostgreSQL with minimum configuration (`db-f1-micro`)  
✅ Private IP only (no public access)  
✅ IAM authentication (no password management)  
✅ Cloud SQL Proxy sidecar in JupyterHub pods  
✅ Workload Identity for secure authentication  
✅ Tested with dummy data insertion and retrieval  
✅ Works from JupyterHub user sessions  

## Outputs

After deployment, Terraform outputs:

```
cloudsql_connection_name = suman-110797:us-central1:jupyterhub-db-instance
cloudsql_private_ip = 10.37.0.3
db_user = jupyter-user-sa@suman-110797.iam
jupyter_user_sa_email = jupyter-user-sa@suman-110797.iam.gserviceaccount.com
kubernetes_cluster_host = 35.224.170.169
kubernetes_cluster_name = jupyterhub-cluster
region = us-central1
shared_bucket_name = suman-110797-jupyterhub-shared
```

## Cleanup

```bash
# Delete JupyterHub
helm uninstall jhub --namespace jhub

# Delete infrastructure
cd infra
terraform destroy -var="project_id=$PROJECT_ID"
```

## Troubleshooting

### Check Cloud SQL Proxy logs

```bash
kubectl logs <pod-name> -n jhub -c cloud-sql-proxy
```

### Check database permissions

```bash
gcloud sql users list --instance=jupyterhub-db-instance
```

### Verify Workload Identity

```bash
kubectl describe sa jupyter-user-sa -n jhub
gcloud iam service-accounts get-iam-policy jupyter-user-sa@suman-110797.iam.gserviceaccount.com
```

## Notes

- The Cloud SQL instance uses `db-f1-micro` which is the smallest tier available
- IAM authentication must be enabled on the Cloud SQL instance (`cloudsql.iam_authentication=on`)
- The postgres user password was set temporarily for granting permissions, but IAM users don't need it
- All database connections from JupyterHub use IAM authentication automatically
