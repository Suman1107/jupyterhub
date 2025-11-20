# JupyterHub with Cloud SQL PostgreSQL Integration

This document provides detailed information about the Cloud SQL PostgreSQL setup for JupyterHub, including both internal (JupyterHub pods) and external (pgAdmin, psql) access.

## Architecture Overview

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
   - **Private IP only** (no public IP): `10.37.0.3`
   - IAM authentication enabled
   - Located in private VPC

4. **Cloud SQL Proxy VM** (for external access)
   - Dual-NIC VM (`e2-micro`)
   - **Public IP**: `35.226.231.27` (static)
   - **Private IP**: Connected to VPC for DB access
   - Runs Cloud SQL Proxy as systemd service
   - Firewall-protected

5. **Service Accounts**
   - `jupyter-user-sa`: For JupyterHub pods
     - `roles/cloudsql.client`
     - `roles/cloudsql.instanceUser`
     - `roles/storage.objectAdmin` (for GCS bucket)
     - Workload Identity binding to K8s SA
   - `cloudsql-proxy`: For Proxy VM
     - `roles/cloudsql.client`
     - `roles/cloudsql.instanceUser`

## Database Access Methods

### 1. Internal Access (JupyterHub Pods)

**Connection Details**:
- **Host**: `127.0.0.1` (via Cloud SQL Proxy sidecar)
- **Port**: `5432`
- **Database**: `jupyterhub_db`
- **User**: `jupyter-user-sa@suman-110797.iam`
- **Authentication**: IAM (automatic via Cloud SQL Proxy)

**How it works**:
- Each JupyterHub pod has a Cloud SQL Proxy sidecar container
- Proxy authenticates using Workload Identity
- Users connect to `localhost:5432` which forwards to Cloud SQL
- No passwords needed - IAM handles authentication

### 2. External Access (pgAdmin, psql, etc.)

**Connection Details**:
- **Host**: `35.226.231.27` (Proxy VM public IP)
- **Port**: `5432`
- **Database**: `jupyterhub_db`
- **User**: `postgres_user`
- **Password**: `postgres` (default, configurable)

**How it works**:
- Proxy VM has two network interfaces:
  - NIC0: Public network for external connections
  - NIC1: Private network for Cloud SQL access
- Cloud SQL Proxy runs as systemd service on the VM
- Listens on `0.0.0.0:5432` for external connections
- Routes traffic to Cloud SQL via private network

## Testing Database Connection

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

### From pgAdmin (External)

1. Open pgAdmin
2. Create a new server:
   - **General Tab**:
     - Name: JupyterHub DB
   - **Connection Tab**:
     - Host: `35.226.231.27`
     - Port: `5432`
     - Database: `jupyterhub_db`
     - Username: `postgres_user`
     - Password: `postgres`
   - **Parameters Tab**:
     - SSL Mode: Prefer

### From psql (External)

```bash
psql -h 35.226.231.27 -p 5432 -U postgres_user -d jupyterhub_db
```

### From a Test Pod (Internal)

```bash
kubectl apply -f k8s/test-pod.yaml
kubectl logs test-db-pod -n jhub -c test-container
```

## Deployment

All infrastructure is now deployed from a single location:

```bash
cd infra
terraform init
terraform apply
```

This creates:
- VPC, GKE, Cloud SQL
- Cloud SQL Proxy VM
- Service accounts
- IAM bindings
- Database users

## Configuration Files

- `infra/main.tf` - Core infrastructure (VPC, GKE, Cloud SQL)
- `infra/proxy.tf` - Cloud SQL Proxy VM configuration
- `infra/startup-script.sh.tftpl` - Proxy VM initialization
- `helm/config.yaml` - JupyterHub Helm values
- `k8s/service-account.yaml` - Kubernetes service account with Workload Identity

## Key Features

✅ **Private Cloud SQL** - No public IP, only accessible via private network  
✅ **Dual Access** - Internal (JupyterHub) and external (pgAdmin) access  
✅ **IAM Authentication** - For JupyterHub pods (no password management)  
✅ **Password Authentication** - For external tools (configurable password)  
✅ **Static IP** - Proxy VM has permanent public IP  
✅ **Automated Setup** - Everything created via Terraform  
✅ **Firewall Protected** - Proxy access restricted by IP  

## Terraform Outputs

After deployment:

```bash
cd infra
terraform output
```

Key outputs:
```
cloudsql_connection_name = suman-110797:us-central1:jupyterhub-db-instance
cloudsql_private_ip = 10.37.0.3
db_user = jupyter-user-sa@suman-110797.iam
proxy_public_ip = 35.226.231.27
proxy_connection_command = psql -h 35.226.231.27 -p 5432 -U postgres_user -d jupyterhub_db
dns_connection_address = db.jupyterhub-proxy.com
```

## Security Considerations

### Internal Access (JupyterHub)
- ✅ Uses IAM authentication
- ✅ No passwords stored or managed
- ✅ Workload Identity for secure authentication
- ✅ Private IP only
- ✅ Network policies restrict pod communication

### External Access (Proxy)
- ⚠️ Uses password authentication (simpler for tools like pgAdmin)
- ✅ Firewall rules restrict access by IP
- ✅ Separate network interfaces (public/private)
- ✅ Static routes ensure traffic isolation
- 💡 **Recommendation**: Restrict `allowed_ips` in `infra/variables.tf` to your IP

## Troubleshooting

### Check Cloud SQL Proxy (JupyterHub sidecar)

```bash
kubectl logs <pod-name> -n jhub -c cloud-sql-proxy
```

### Check Cloud SQL Proxy VM

```bash
# SSH into VM
gcloud compute ssh cloudsql-proxy-vm --zone=us-central1-a

# Check service status
sudo systemctl status cloud-sql-proxy

# View logs
sudo journalctl -u cloud-sql-proxy -f

# Check routing
ip route
# Should show: 10.0.0.0/8 via 192.168.0.1
```

### Test Connectivity

```bash
# From your machine
nc -zv 35.226.231.27 5432

# Should output: Connection to 35.226.231.27 port 5432 [tcp/postgresql] succeeded!
```

### Check Database Users

```bash
gcloud sql users list --instance=jupyterhub-db-instance
```

### Verify Workload Identity

```bash
kubectl describe sa jupyter-user-sa -n jhub
gcloud iam service-accounts get-iam-policy \
    jupyter-user-sa@suman-110797.iam.gserviceaccount.com
```

## Customization

### Change Proxy Password

Edit `infra/variables.tf`:
```hcl
variable "db_password" {
  default = "your-secure-password"
}
```

Then run:
```bash
cd infra
terraform apply
```

### Restrict Proxy Access

Edit `infra/variables.tf`:
```hcl
variable "allowed_ips" {
  default = ["YOUR_PUBLIC_IP/32"]
}
```

### Change Database Tier

Edit `infra/main.tf`:
```hcl
settings {
  tier = "db-g1-small"  # Upgrade from db-f1-micro
}
```

## Cleanup

```bash
cd infra
terraform destroy
```

This will remove:
- GKE cluster and all workloads
- Cloud SQL instance and all data
- Proxy VM
- All associated resources

## Additional Resources

- [Cloud SQL Proxy Documentation](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [IAM Database Authentication](https://cloud.google.com/sql/docs/postgres/authentication)
- [`infra/README.md`](infra/README.md) - Detailed infrastructure documentation
