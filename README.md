# JupyterHub with Cloud SQL PostgreSQL - Complete Deployment Guide

This repository contains everything needed to deploy JupyterHub on GKE with Cloud SQL PostgreSQL integration using IAM authentication, plus a Cloud SQL Proxy for external database access.

## 🎯 What This Deploys

- **Private VPC** with CIDR `192.168.0.0/24`
- **GKE Cluster** with Workload Identity and GCS FUSE
- **Cloud SQL PostgreSQL** (db-f1-micro) with IAM authentication
- **Cloud SQL Proxy VM** for external access (pgAdmin, etc.)
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

### 3. Deploy Infrastructure

```bash
cd infra
terraform init
terraform apply  # Uses default project_id: suman-110797
```

This single command deploys:
- VPC, GKE, Cloud SQL
- Cloud SQL Proxy VM with static IP
- Service accounts and IAM bindings
- DNS (optional)

### 4. Deploy JupyterHub

```bash
# Get cluster credentials
gcloud container clusters get-credentials jupyterhub-cluster \
    --zone=us-central1-a

# Create namespace and service account
kubectl create namespace jhub
kubectl apply -f k8s/service-account.yaml

# Install JupyterHub
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
helm upgrade --install jhub jupyterhub/jupyterhub \
    --namespace jhub \
    --version 3.3.8 \
    --values helm/config.yaml
```

### 5. Access JupyterHub

```bash
kubectl --namespace=jhub port-forward service/proxy-public 8080:80
```

Then open: **http://localhost:8080**

## 🔌 External Database Access

The infrastructure includes a Cloud SQL Proxy VM for connecting from tools like pgAdmin:

**Connection Details** (from `terraform output`):
- **Host**: `35.226.231.27` (Static IP)
- **Port**: `5432`
- **Database**: `jupyterhub_db`
- **Username**: `postgres_user`
- **Password**: `postgres` (default, configurable)

See [`infra/README.md`](infra/README.md) for detailed proxy documentation.

## 📁 Repository Structure

```
.
├── infra/                       # 🏗️ Terraform infrastructure (ALL-IN-ONE)
│   ├── main.tf                  # Core infrastructure (VPC, GKE, Cloud SQL)
│   ├── proxy.tf                 # Cloud SQL Proxy VM for external access
│   ├── kms.tf                   # KMS encryption keys
│   ├── variables.tf             # Variables (with defaults)
│   ├── outputs.tf               # Outputs (IPs, connection strings)
│   ├── startup-script.sh.tftpl  # Proxy VM initialization
│   └── README.md                # Detailed infrastructure docs
├── helm/                        # Helm configuration
│   └── config.yaml              # JupyterHub Helm values
├── k8s/                         # Kubernetes manifests
│   ├── service-account.yaml     # Workload Identity SA
│   └── test-pod.yaml            # Database test pod
├── scripts/                     # Helper scripts
│   ├── jupyterhub_db_test.py    # User test script
│   └── test_db.py               # Pod test script
├── deploy.sh                    # Automated deployment script
└── cleanup.sh                   # Cleanup/destroy script
```

## 🔧 Manual Deployment (Step by Step)

If you prefer to deploy manually:

### Step 1: Deploy Infrastructure

```bash
cd infra
terraform init
terraform apply
```

This creates:
- VPC and subnet
- GKE cluster
- Cloud SQL instance
- Cloud SQL Proxy VM
- Service accounts
- IAM bindings

### Step 2: Get GKE Credentials

```bash
gcloud container clusters get-credentials jupyterhub-cluster \
    --zone=us-central1-a
```

### Step 3: Create Kubernetes Resources

```bash
kubectl create namespace jhub
kubectl apply -f k8s/service-account.yaml
```

### Step 4: Install JupyterHub

```bash
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
helm upgrade --install jhub jupyterhub/jupyterhub \
    --namespace jhub \
    --version 3.3.8 \
    --values helm/config.yaml
```

## 🧪 Testing

### Test JupyterHub Database Connection

1. Log into JupyterHub
2. Create a new Python notebook
3. Copy and run `scripts/jupyterhub_db_test.py`

### Test External Database Connection

Use pgAdmin or psql with the proxy connection details:

```bash
psql -h 35.226.231.27 -p 5432 -U postgres_user -d jupyterhub_db
```

## 🗑️ Cleanup

To destroy all resources:

```bash
cd infra
terraform destroy
```

This will remove:
- GKE cluster and all workloads
- Cloud SQL instance and data
- Proxy VM
- All associated resources

## 📊 Terraform Outputs

After deployment:

```bash
cd infra
terraform output
```

Key outputs:
- `proxy_public_ip` - Static IP for external access
- `proxy_connection_command` - Ready-to-use psql command
- `cloudsql_connection_name` - Cloud SQL connection string
- `cloudsql_private_ip` - Private IP of database
- `shared_bucket_name` - GCS bucket name

## 🔒 Security Features

✅ **Private VPC** - All resources in isolated network  
✅ **No Public Database** - Cloud SQL only accessible via private IP  
✅ **IAM Authentication** - No password management for JupyterHub  
✅ **Workload Identity** - Secure GCP access from pods  
✅ **Firewall Rules** - Restricted proxy access  
✅ **Secure Boot** - Enabled on GKE nodes  
✅ **Dual-NIC Proxy** - Isolated public/private networks  

## 🛠️ Customization

### Change Allowed IPs for Proxy

Edit `infra/variables.tf`:
```hcl
variable "allowed_ips" {
  default = ["YOUR_IP/32"]  # Restrict to your IP
}
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
2. **Default Project**: Set to `suman-110797` in `infra/variables.tf`
3. **Proxy Password**: Default is `postgres`, change via `db_password` variable
4. **Static IP**: Proxy VM has permanent IP that survives recreation
5. **Dual Access**: Database accessible both internally (JupyterHub) and externally (pgAdmin)

## 🐛 Troubleshooting

### Check JupyterHub Pods

```bash
kubectl get pods -n jhub
kubectl describe pod <pod-name> -n jhub
```

### Check Cloud SQL Proxy (Internal)

```bash
kubectl logs <pod-name> -n jhub -c cloud-sql-proxy
```

### Check Cloud SQL Proxy VM (External)

```bash
gcloud compute ssh cloudsql-proxy-vm --zone=us-central1-a
sudo systemctl status cloud-sql-proxy
sudo journalctl -u cloud-sql-proxy -f
```

### Verify Connectivity

```bash
nc -zv 35.226.231.27 5432
```

## 📚 Additional Documentation

- [`infra/README.md`](infra/README.md) - Detailed infrastructure documentation
- [DATABASE_SETUP.md](DATABASE_SETUP.md) - Database setup guide (legacy)
- [Terraform Docs](https://www.terraform.io/docs)
- [JupyterHub Helm Chart](https://zero-to-jupyterhub.readthedocs.io/)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)

## 💰 Cost Estimation

Estimated monthly cost (us-central1):
- **GKE**: ~$150/month (2 e2-standard-4 nodes)
- **Cloud SQL**: ~$10/month (db-f1-micro)
- **Proxy VM**: ~$7/month (e2-micro)
- **Storage**: ~$1/month (minimal usage)
- **Total**: ~$168/month

To minimize costs:
- Stop GKE cluster when not in use
- Stop Proxy VM when not needed: `gcloud compute instances stop cloudsql-proxy-vm`
- Use preemptible nodes (edit infra/main.tf)

## 🤝 Contributing

Feel free to submit issues or pull requests!

## 📄 License

MIT License
