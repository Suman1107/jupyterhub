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

2. **Deploy Everything**
   ```bash
   ./deploy.sh <your-new-project-id>
   ```
   
   Wait 10-15 minutes for deployment to complete.

3. **Access JupyterHub**
   ```bash
   kubectl --namespace=jhub port-forward service/proxy-public 8080:80
   ```
   
   Open: http://localhost:8080

4. **Test Database**
   - Log into JupyterHub
   - Create a new Python notebook
   - Copy and run the code from `scripts/jupyterhub_db_test.py`

### What Gets Created

- Private VPC (192.168.0.0/24)
- GKE Cluster (2 nodes, e2-standard-4)
- Cloud SQL PostgreSQL (db-f1-micro)
- Service Account with IAM roles
- GCS Bucket for shared storage
- JupyterHub with database access

### Cleanup

```bash
./cleanup.sh <your-project-id>
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
- Storage: ~$1/month (minimal usage)
- **Total: ~$160/month**

To minimize costs:
- Stop GKE cluster when not in use
- Use preemptible nodes (edit infra/main.tf)
- Use smaller machine types
