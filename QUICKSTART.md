# Quick Start Guide

## For a Brand New GCP Project

### Prerequisites
- GCP account with billing enabled
- gcloud CLI installed
- kubectl installed
- Terraform installed
- Helm installed

### Steps

1. **Authenticate**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Deploy Infrastructure**
   ```bash
   cd infra
   terraform init
   terraform apply
   ```
   
   Wait 5-10 minutes for deployment to complete.
   
   **Note**: Default project is `suman-110797`. Override with:
   ```bash
   terraform apply -var="project_id=your-project-id"
   ```

3. **Deploy JupyterHub**
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

4. **Access JupyterHub**
   ```bash
   kubectl --namespace=jhub port-forward service/proxy-public 8080:80
   ```
   
   Open: http://localhost:8080

5. **Test Database (Optional)**
   - Log into JupyterHub
   - Create a new Python notebook
   - Copy and run the code from `scripts/jupyterhub_db_test.py`

6. **Connect from pgAdmin (Optional)**
   
   Get connection details:
   ```bash
   cd infra
   terraform output proxy_public_ip
   terraform output proxy_connection_command
   ```
   
   Use in pgAdmin:
   - Host: `<proxy_public_ip>`
   - Port: `5432`
   - User: `postgres_user`
   - Password: `postgres`
   - Database: `jupyterhub_db`

### What Gets Created

**Core Infrastructure**:
- Private VPC (192.168.0.0/24)
- GKE Cluster (2 nodes, e2-standard-4)
- Cloud SQL PostgreSQL (db-f1-micro, private IP only)
- Service Accounts with IAM roles
- GCS Bucket for shared storage

**External Access**:
- Cloud SQL Proxy VM (e2-micro)
- Static Public IP
- Dual-NIC configuration (public + private)
- Firewall rules
- DNS zone (optional)

**JupyterHub**:
- Individual persistent disks per user
- Shared GCS bucket mount
- Cloud SQL Proxy sidecar
- IAM authentication

### Cleanup

```bash
# Delete JupyterHub
helm uninstall jhub --namespace jhub
kubectl delete namespace jhub

# Destroy infrastructure
cd infra
terraform destroy
```

### Troubleshooting

If deployment fails:
1. Check you have billing enabled
2. Verify you have necessary permissions
3. Check the error message and retry
4. See README.md for detailed troubleshooting

### Costs

Estimated monthly cost (us-central1):
- GKE: ~$150/month (2 e2-standard-4 nodes)
- Cloud SQL: ~$10/month (db-f1-micro)
- Proxy VM: ~$7/month (e2-micro)
- Storage: ~$1/month (minimal usage)
- **Total: ~$168/month**

To minimize costs:
- Stop GKE cluster when not in use
- Stop Proxy VM: `gcloud compute instances stop cloudsql-proxy-vm --zone=us-central1-a`
- Use preemptible nodes (edit infra/main.tf)
- Use smaller machine types

### Next Steps

- Read [`infra/README.md`](infra/README.md) for detailed infrastructure docs
- Read [`README.md`](README.md) for complete deployment guide
- Customize `infra/variables.tf` for your needs
- Restrict `allowed_ips` in variables for security
