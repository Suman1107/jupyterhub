# JupyterHub Infrastructure

This folder contains the complete infrastructure-as-code for deploying JupyterHub on GKE with Cloud SQL and external access via a Cloud SQL Proxy.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      JupyterHub on GKE                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ - Individual Persistent Disks per User                   │  │
│  │ - Shared GCS Bucket (mounted via GCS FUSE)              │  │
│  │ - Cloud SQL Proxy Sidecar (IAM Auth)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Cloud SQL PostgreSQL                         │
│              (Private IP: 10.37.0.3)                           │
│  - IAM Authentication Enabled                                   │
│  - Private VPC Peering                                         │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────┴───────────────────────────────────┐
│              Cloud SQL Proxy VM (Dual-NIC)                      │
│  ┌────────────────────────────────────────────────────────────┐│
│  │ NIC0: Public (35.226.231.27) - For pgAdmin Access         ││
│  │ NIC1: Private (192.168.0.x) - For DB Access               ││
│  └────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Core Infrastructure (`main.tf`)
- **GKE Cluster**: Zonal cluster with Workload Identity and GCS FUSE CSI driver
- **VPC Network**: Custom VPC (`192.168.0.0/24`) with private subnet
- **Cloud SQL**: PostgreSQL 15 instance with private IP and IAM authentication
- **Service Accounts**: 
  - `jupyter-user-sa`: For JupyterHub pods to access GCS and Cloud SQL
  - `cloudsql-proxy`: For external proxy access

### Cloud SQL Proxy (`proxy.tf`)
- **Dual-NIC VM**: 
  - Public interface for external connections
  - Private interface for Cloud SQL access
- **Static Public IP**: Permanent IP address for stable connections
- **Automated Routing**: Startup script configures routing for private DB access
- **DNS**: Optional public DNS zone for friendly names
- **Database User**: Automatically creates `postgres_user` for external access

### Security (`kms.tf`)
- **KMS Key Ring**: For encrypting JupyterHub auth tokens
- **IAM Bindings**: Least-privilege access controls

## Deployment

### Prerequisites
- GCP Project with billing enabled
- Terraform installed
- `gcloud` CLI authenticated

### Quick Start

1. **Initialize Terraform**:
   ```bash
   cd infra
   terraform init
   ```

2. **Deploy Infrastructure**:
   ```bash
   terraform apply
   ```
   
   The `project_id` defaults to `suman-110797`. Override if needed:
   ```bash
   terraform apply -var="project_id=your-project-id"
   ```

3. **Get Connection Details**:
   ```bash
   terraform output proxy_connection_command
   terraform output proxy_public_ip
   ```

## Connecting to the Database

### From pgAdmin (External)

Use the Cloud SQL Proxy VM to connect from your local machine:

| Parameter | Value |
|-----------|-------|
| **Host** | `35.226.231.27` (from `proxy_public_ip` output) |
| **Port** | `5432` |
| **Database** | `jupyterhub_db` |
| **Username** | `postgres_user` |
| **Password** | `postgres` (default, configurable via `db_password` variable) |

### From JupyterHub Pods (Internal)

JupyterHub pods connect via the Cloud SQL Proxy sidecar using IAM authentication:
- **Host**: `127.0.0.1` (localhost via sidecar)
- **Port**: `5432`
- **User**: `jupyter-user-sa@suman-110797.iam`
- **Auth**: Automatic via Workload Identity

## Configuration

### Variables

Edit `variables.tf` or pass via command line:

```hcl
# Core
project_id = "suman-110797"  # Default set
region     = "us-central1"

# Proxy Security
allowed_ips = ["YOUR_IP/32"]  # Restrict to your IP for security

# Database
db_password = "postgres"  # Password for postgres_user

# DNS (optional)
dns_domain = "your-domain.com"
```

### Customization

- **Proxy VM Size**: Edit `machine_type` in `proxy.tf` (default: `e2-micro`)
- **Database Tier**: Edit `tier` in `main.tf` (default: `db-f1-micro`)
- **GKE Node Count**: Edit `node_count` in `main.tf` (default: 2)

## Outputs

After deployment, Terraform provides:

```
cloudsql_connection_name    = Connection string for Cloud SQL
cloudsql_private_ip         = Private IP of the database
proxy_public_ip             = Public IP of the proxy VM
proxy_connection_command    = Ready-to-use psql command
dns_connection_address      = DNS name (if configured)
jupyter_user_sa_email       = Service account email for JupyterHub
```

## Troubleshooting

### Proxy Connection Issues

1. **Check Proxy Status**:
   ```bash
   gcloud compute ssh cloudsql-proxy-vm --zone=us-central1-a
   sudo systemctl status cloud-sql-proxy
   sudo journalctl -u cloud-sql-proxy -f
   ```

2. **Verify Routing**:
   ```bash
   ip route
   # Should show: 10.0.0.0/8 via 192.168.0.1
   ```

3. **Test Port**:
   ```bash
   nc -zv 35.226.231.27 5432
   ```

### Database Access Issues

1. **Check IAM Permissions**:
   ```bash
   gcloud sql users list --instance=jupyterhub-db-instance
   ```

2. **Verify Workload Identity**:
   ```bash
   kubectl describe sa jupyter-user-sa -n jhub
   ```

## Cleanup

To destroy all infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete:
- GKE cluster and all workloads
- Cloud SQL instance and all data
- Proxy VM
- All associated resources

## Files

- `main.tf`: Core infrastructure (VPC, GKE, Cloud SQL, Service Accounts)
- `proxy.tf`: Cloud SQL Proxy VM and networking
- `kms.tf`: KMS key ring for encryption
- `variables.tf`: Input variables
- `outputs.tf`: Output values
- `startup-script.sh.tftpl`: VM initialization script

## Security Best Practices

✅ **Implemented**:
- Private Cloud SQL (no public IP)
- IAM authentication for database access
- Workload Identity for pod-level permissions
- Firewall rules restricting proxy access
- KMS encryption for sensitive data

⚠️ **Recommendations**:
- Restrict `allowed_ips` to your specific IP address
- Use a strong `db_password` (not the default)
- Enable deletion protection for production databases
- Implement backup policies for Cloud SQL

## Cost Optimization

- **Proxy VM**: Stop when not in use (`gcloud compute instances stop cloudsql-proxy-vm`)
- **GKE**: Use preemptible nodes for non-production
- **Cloud SQL**: Use smallest tier (`db-f1-micro`) for development

## Next Steps

1. Deploy JupyterHub:
   ```bash
   cd ../helm
   helm upgrade --install jhub jupyterhub/jupyterhub \
     --namespace jhub \
     --values config.yaml
   ```

2. Access JupyterHub:
   ```bash
   kubectl --namespace=jhub port-forward service/proxy-public 8080:80
   ```

3. Connect to database from pgAdmin using the proxy IP

## Support

For issues or questions, refer to:
- [JupyterHub Documentation](https://zero-to-jupyterhub.readthedocs.io/)
- [Cloud SQL Proxy Documentation](https://cloud.google.com/sql/docs/mysql/sql-proxy)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
