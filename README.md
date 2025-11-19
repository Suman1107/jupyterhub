# JupyterHub with Cloud SQL PostgreSQL - Complete Deployment Guide

This repository contains everything needed to deploy JupyterHub on GKE with Cloud SQL PostgreSQL integration using IAM authentication.

## 🎯 What This Deploys

- **Private VPC** with CIDR `192.168.0.0/24`
- **GKE Cluster** with Workload Identity and GCS FUSE
- **Cloud SQL PostgreSQL** (db-f1-micro) with IAM authentication
- **JupyterHub** with:
  - Individual persistent disks per user
  - Shared GCS bucket
  - Cloud SQL Proxy sidecar for database access
  - IAM-based authentication (no passwords!)

## 📋 Prerequisites

1. **GCP Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **kubectl** installed
4. **Terraform** (v1.5+) installed
5. **Helm** (v3+) installed

## 🚀 Quick Start (Automated Deployment)

### 1. Clone this repository

```bash
git clone <your-repo>
cd JupyterHub
```

### 2. Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
```

### 3. Run the deployment script

```bash
./deploy.sh <your-project-id> [region]
```

**Example:**
```bash
./deploy.sh my-new-project us-central1
```

The script will:
1. ✅ Enable required GCP APIs
2. ✅ Deploy infrastructure with Terraform
3. ✅ Configure GKE cluster
4. ✅ Install JupyterHub with Helm
5. ✅ Grant database permissions
6. ✅ Display access instructions

### 4. Access JupyterHub

```bash
kubectl --namespace=jhub port-forward service/proxy-public 8080:80
```

Then open: **http://localhost:8080**

## 📁 Repository Structure

```
.
├── deploy.sh                    # Main deployment script
├── cleanup.sh                   # Cleanup/destroy script
├── DATABASE_SETUP.md            # Detailed database setup documentation
├── infra/                       # Terraform infrastructure
│   ├── main.tf                  # Main infrastructure definition
│   ├── variables.tf             # Input variables
│   └── outputs.tf               # Output values
├── helm/                        # Helm configuration
│   └── config.yaml              # JupyterHub Helm values
├── k8s/                         # Kubernetes manifests
│   ├── service-account.yaml     # Workload Identity SA
│   ├── test-pod.yaml            # Database test pod
│   └── grant-permissions-pod.yaml # Permission granting pod
└── scripts/                     # Helper scripts
    ├── grant_db_permissions.sh  # Grant DB permissions
    ├── jupyterhub_db_test.py    # User test script
    └── test_db.py               # Pod test script
```

## 🔧 Manual Deployment (Step by Step)

If you prefer to deploy manually:

### Step 1: Enable APIs

```bash
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    servicenetworking.googleapis.com \
    storage.googleapis.com \
    --project=<your-project-id>
```

### Step 2: Deploy Infrastructure

```bash
cd infra
terraform init
terraform apply -var="project_id=<your-project-id>"
```

### Step 3: Get GKE Credentials

```bash
gcloud container clusters get-credentials jupyterhub-cluster \
    --zone=us-central1-a \
    --project=<your-project-id>
```

### Step 4: Create Kubernetes Resources

```bash
kubectl create namespace jhub
kubectl apply -f k8s/service-account.yaml
```

### Step 5: Install JupyterHub

```bash
# Update helm/config.yaml with your bucket name and project ID
# Then install:
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
helm upgrade --install jhub jupyterhub/jupyterhub \
    --namespace jhub \
    --version 3.3.8 \
    --values helm/config.yaml
```

### Step 6: Grant Database Permissions

```bash
./scripts/grant_db_permissions.sh <your-project-id>
```

## 🧪 Testing Database Connection

### From a Test Pod

```bash
kubectl apply -f k8s/test-pod.yaml
kubectl logs test-db-pod -n jhub -c test-container
```

### From JupyterHub Notebook

1. Log into JupyterHub
2. Create a new Python notebook
3. Copy and run `scripts/jupyterhub_db_test.py`

## 🔑 Key Configuration Files

### Terraform (`infra/main.tf`)

- Defines VPC, GKE, Cloud SQL, and IAM resources
- Enables IAM authentication on Cloud SQL
- Creates service account with necessary permissions
- Generates random postgres password

### Helm Values (`helm/config.yaml`)

- Configures JupyterHub with:
  - Cloud SQL Proxy sidecar
  - GCS bucket mount
  - Workload Identity
  - Network policies

### Service Account (`k8s/service-account.yaml`)

- Links Kubernetes SA to Google SA via Workload Identity
- Enables IAM authentication for database access

## 🗑️ Cleanup

To destroy all resources:

```bash
./cleanup.sh <your-project-id>
```

This will:
1. Uninstall JupyterHub
2. Delete Kubernetes namespace
3. Destroy all Terraform resources

## 📊 Terraform Outputs

After deployment, you can view outputs:

```bash
cd infra
terraform output
```

Key outputs:
- `project_id` - Your GCP project ID
- `cloudsql_connection_name` - Cloud SQL connection string
- `cloudsql_private_ip` - Private IP of database
- `db_user` - IAM database user
- `shared_bucket_name` - GCS bucket name
- `postgres_password` - Postgres password (sensitive)

## 🔒 Security Features

✅ **Private VPC** - All resources in isolated network  
✅ **No Public IPs** - Database only accessible via private IP  
✅ **IAM Authentication** - No password management needed  
✅ **Workload Identity** - Secure GCP access from pods  
✅ **Network Policies** - Restricted pod-to-pod communication  
✅ **Secure Boot** - Enabled on GKE nodes  

## 🛠️ Customization

### Change Region

```bash
./deploy.sh <project-id> europe-west1
```

### Modify Database Size

Edit `infra/main.tf`:
```hcl
settings {
  tier = "db-g1-small"  # Change from db-f1-micro
}
```

### Adjust Node Count

Edit `infra/main.tf`:
```hcl
node_count = 3  # Change from 2
```

## 📝 Important Notes

1. **First Deployment**: Takes ~10-15 minutes
2. **IAM Authentication**: Automatically handled by Cloud SQL Proxy
3. **Postgres User**: Created with random password for initial setup
4. **Database Permissions**: Automatically granted via script
5. **Bucket Name**: Auto-generated as `<project-id>-jupyterhub-shared`

## 🐛 Troubleshooting

### Check JupyterHub Pods

```bash
kubectl get pods -n jhub
kubectl describe pod <pod-name> -n jhub
```

### Check Cloud SQL Proxy Logs

```bash
kubectl logs <pod-name> -n jhub -c cloud-sql-proxy
```

### Verify Workload Identity

```bash
kubectl describe sa jupyter-user-sa -n jhub
gcloud iam service-accounts get-iam-policy \
    jupyter-user-sa@<project-id>.iam.gserviceaccount.com
```

### Test Database Connection

```bash
kubectl apply -f k8s/test-pod.yaml
kubectl logs test-db-pod -n jhub -c test-container
```

## 📚 Additional Documentation

- [DATABASE_SETUP.md](DATABASE_SETUP.md) - Detailed database setup guide
- [Terraform Docs](https://www.terraform.io/docs)
- [JupyterHub Helm Chart](https://zero-to-jupyterhub.readthedocs.io/)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)

## 🤝 Contributing

Feel free to submit issues or pull requests!

## 📄 License

MIT License
