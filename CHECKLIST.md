# Deployment Checklist

Use this checklist to verify everything is properly configured before deploying to a new project.

## ✅ Pre-Deployment Checklist

### Files Present
- [ ] `deploy.sh` - Main deployment script
- [ ] `cleanup.sh` - Cleanup script
- [ ] `README.md` - Main documentation
- [ ] `QUICKSTART.md` - Quick start guide
- [ ] `DATABASE_SETUP.md` - Database documentation
- [ ] `.gitignore` - Git ignore file

### Terraform Files
- [ ] `infra/main.tf` - Infrastructure definition
- [ ] `infra/variables.tf` - Variables
- [ ] `infra/outputs.tf` - Outputs
- [ ] Terraform includes IAM authentication flag
- [ ] Terraform includes random password for postgres
- [ ] Terraform includes all required providers

### Kubernetes Files
- [ ] `k8s/service-account.yaml` - Workload Identity SA
- [ ] `k8s/test-pod.yaml` - Test pod
- [ ] `k8s/grant-permissions-pod.yaml` - Permissions pod

### Helm Files
- [ ] `helm/config.yaml` - JupyterHub configuration
- [ ] Config includes Cloud SQL Proxy sidecar
- [ ] Config includes GCS bucket mount
- [ ] Config includes Workload Identity SA

### Scripts
- [ ] `scripts/grant_db_permissions.sh` - Grant permissions
- [ ] `scripts/jupyterhub_db_test.py` - User test script
- [ ] `scripts/test_db.py` - Pod test script
- [ ] All scripts are executable (`chmod +x`)

## ✅ Deployment Steps Verification

### Step 1: Enable APIs
- [ ] container.googleapis.com
- [ ] compute.googleapis.com
- [ ] sqladmin.googleapis.com
- [ ] servicenetworking.googleapis.com
- [ ] storage.googleapis.com

### Step 2: Terraform Apply
- [ ] VPC created
- [ ] Subnet created (192.168.0.0/24)
- [ ] GKE cluster created
- [ ] Cloud SQL instance created
- [ ] Database created
- [ ] Service account created
- [ ] IAM bindings created
- [ ] GCS bucket created

### Step 3: Kubernetes Setup
- [ ] Namespace 'jhub' created
- [ ] Service account created
- [ ] Workload Identity annotation present

### Step 4: JupyterHub Installation
- [ ] Helm repo added
- [ ] JupyterHub installed
- [ ] Hub pod running
- [ ] Proxy pod running
- [ ] User scheduler pods running

### Step 5: Database Permissions
- [ ] Permissions granted to IAM user
- [ ] Can create tables
- [ ] Can insert data
- [ ] Can query data

## ✅ Post-Deployment Verification

### Infrastructure
- [ ] Can access GKE cluster with kubectl
- [ ] All pods in 'jhub' namespace are Running
- [ ] Cloud SQL instance is RUNNABLE
- [ ] Database 'jupyterhub_db' exists
- [ ] IAM user exists in database

### JupyterHub
- [ ] Can access JupyterHub UI
- [ ] Can create new user
- [ ] Can start user server
- [ ] User pod includes cloud-sql-proxy container
- [ ] Shared GCS bucket is mounted
- [ ] Individual PVC is created

### Database Connection
- [ ] Test pod can connect to database
- [ ] Can create tables
- [ ] Can insert data
- [ ] Can query data
- [ ] IAM authentication works

### From JupyterHub User
- [ ] Can run jupyterhub_db_test.py
- [ ] Script connects successfully
- [ ] Can create tables
- [ ] Can insert data
- [ ] Can fetch data

## 🔧 Configuration Variables to Update

When deploying to a new project, these will be automatically updated by the deploy script:

- [ ] Project ID in Terraform variables
- [ ] Bucket name in helm/config.yaml
- [ ] Cloud SQL connection string in helm/config.yaml
- [ ] Service account email references

## 📋 Manual Steps (if not using deploy.sh)

If deploying manually, remember to:

1. [ ] Update `helm/config.yaml` with correct bucket name
2. [ ] Update `helm/config.yaml` with correct project ID in Cloud SQL Proxy args
3. [ ] Run grant_db_permissions.sh after Terraform apply
4. [ ] Wait for all pods to be Ready before testing

## 🎯 Success Criteria

Deployment is successful when:

- [ ] `./deploy.sh <project-id>` completes without errors
- [ ] JupyterHub is accessible at http://localhost:8080
- [ ] Can create and log in as a user
- [ ] User server starts successfully
- [ ] `scripts/jupyterhub_db_test.py` runs successfully in a notebook
- [ ] Data persists across user server restarts
- [ ] Shared bucket is accessible from all users

## 🧹 Cleanup Verification

After running cleanup.sh:

- [ ] JupyterHub uninstalled
- [ ] Namespace deleted
- [ ] All Terraform resources destroyed
- [ ] No lingering PVCs
- [ ] No lingering load balancers
- [ ] GCS bucket deleted (if force_destroy = true)

## 📝 Notes

- First deployment takes 10-15 minutes
- Cloud SQL instance creation takes ~5 minutes
- GKE cluster creation takes ~5 minutes
- Database permissions must be granted after Terraform apply
- All manual steps are automated in deploy.sh
