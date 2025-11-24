# Employee API - Quick Start Guide

This guide will help you get the Employee API up and running quickly.

## Prerequisites Checklist

- [ ] Docker installed and running
- [ ] `gcloud` CLI installed and authenticated
- [ ] `kubectl` installed
- [ ] Terraform >= 1.0 installed
- [ ] Access to GCP project `suman-110797`
- [ ] GKE cluster `jupyterhub-cluster` running in `us-central1-a`

## Option 1: Automated Deployment (Recommended)

Run the automated deployment script:

```bash
cd employee-api-app
./deploy.sh
```

This script will:
1. Configure your GCP project
2. Get GKE credentials
3. Initialize and apply Terraform
4. Build and push the Docker image
5. Deploy to Kubernetes
6. Show you the Ingress IP

## Option 2: Manual Step-by-Step Deployment

### Step 1: Test Locally

```bash
# Build the Docker image
docker build -t employee-api:local .

# Run locally
docker run -p 8080:8080 -v $(pwd)/data:/app/data employee-api:local

# Test in browser
open http://localhost:8080
```

### Step 2: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"

# Apply the configuration
terraform apply \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"
```

This creates:
- Artifact Registry repository
- Kubernetes namespace
- All K8s resources (deployment, service, ingress, HPA, PVC)
- Cloud Build trigger
- Required IAM permissions

### Step 3: Build and Deploy with Cloud Build

```bash
# Get GKE credentials
gcloud container clusters get-credentials jupyterhub-cluster \
  --zone=us-central1-a \
  --project=suman-110797

# Submit build
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=_IMAGE_TAG=v1.0.0 \
  --project=suman-110797
```

### Step 4: Verify Deployment

```bash
# Check all resources
kubectl get all -n employee-api

# Check pods
kubectl get pods -n employee-api

# Check ingress
kubectl get ingress -n employee-api

# View logs
kubectl logs -n employee-api -l app=employee-api --tail=50
```

### Step 5: Access the Application

```bash
# Get the Ingress IP
kubectl get ingress -n employee-api employee-api-ingress

# The output will show:
# NAME                   CLASS   HOSTS   ADDRESS         PORTS   AGE
# employee-api-ingress   nginx   *       <INGRESS_IP>    80      5m

# Open in browser
open http://<INGRESS_IP>
```

## Testing the API

### Using curl

```bash
# Health check
curl http://<INGRESS_IP>/health

# Get all employees
curl http://<INGRESS_IP>/api/employees

# Add an employee
curl -X POST http://<INGRESS_IP>/api/employees \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john.doe@example.com"}'

# Delete an employee
curl -X DELETE http://<INGRESS_IP>/api/employees/john.doe@example.com
```

### Using the Web UI

1. Navigate to `http://<INGRESS_IP>` in your browser
2. Fill in the employee name and email
3. Click "Add Employee"
4. View the employee list below
5. Click "Delete" to remove an employee

## Monitoring

### View Logs

```bash
# Real-time logs
kubectl logs -n employee-api -l app=employee-api -f

# Last 100 lines
kubectl logs -n employee-api -l app=employee-api --tail=100
```

### Check Pod Status

```bash
# Get pod status
kubectl get pods -n employee-api

# Describe a pod
kubectl describe pod -n employee-api <pod-name>
```

### Check HPA Status

```bash
# View autoscaler status
kubectl get hpa -n employee-api

# Describe HPA
kubectl describe hpa -n employee-api employee-api-hpa
```

## Updating the Application

### Update Code and Redeploy

```bash
# Make your code changes, then:

# Build and deploy with new version
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=_IMAGE_TAG=v1.1.0 \
  --project=suman-110797
```

### Update Terraform Configuration

```bash
cd terraform

# Make changes to .tf files, then:
terraform plan -var="project_id=suman-110797" -var="region=us-central1" -var="cluster_name=jupyterhub-cluster" -var="cluster_location=us-central1-a"

terraform apply -var="project_id=suman-110797" -var="region=us-central1" -var="cluster_name=jupyterhub-cluster" -var="cluster_location=us-central1-a"
```

## Scaling

### Manual Scaling

```bash
# Scale to 5 replicas
kubectl scale deployment -n employee-api employee-api --replicas=5
```

### Adjust HPA

Edit `k8s/hpa.yaml` or `terraform/kubernetes.tf` to change min/max replicas or CPU thresholds.

## Troubleshooting

### Pods not starting

```bash
# Check pod events
kubectl describe pod -n employee-api <pod-name>

# Check logs
kubectl logs -n employee-api <pod-name>
```

### Ingress not working

```bash
# Check ingress status
kubectl describe ingress -n employee-api employee-api-ingress

# Verify NGINX ingress controller is running
kubectl get pods -n ingress-nginx
```

### Database issues

```bash
# Check PVC status
kubectl get pvc -n employee-api

# Access database in pod
kubectl exec -it -n employee-api <pod-name> -- sqlite3 /app/data/employees.db
```

### Image pull errors

```bash
# Verify Artifact Registry permissions
gcloud artifacts repositories get-iam-policy employee-api \
  --location=us-central1 \
  --project=suman-110797

# Check if image exists
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/suman-110797/employee-api \
  --project=suman-110797
```

## Integration with Cloud Function

To integrate this API with your Google Group sync Cloud Function:

```python
import requests

# Use internal service DNS if Cloud Function is in same cluster
API_URL = "http://employee-api.employee-api.svc.cluster.local/api/employees"

# Or use Ingress IP if external
# API_URL = "http://<INGRESS_IP>/api/employees"

def sync_employees():
    response = requests.get(API_URL)
    employees = response.json()["employees"]
    
    for employee in employees:
        # Sync to Google Groups
        print(f"Syncing {employee['email']}")
```

## Cleanup

### Remove all resources

```bash
cd terraform
terraform destroy \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"
```

### Or manually delete namespace

```bash
kubectl delete namespace employee-api
```

## Next Steps

1. **Set up DNS**: Point a domain to your Ingress IP
2. **Enable HTTPS**: Configure SSL/TLS certificates
3. **Set up monitoring**: Use Google Cloud Monitoring
4. **Configure backups**: Set up automated database backups
5. **Add authentication**: Implement OAuth or API keys
6. **Connect to GitHub**: Set up automatic builds on push

## Support

For issues:
1. Check logs: `kubectl logs -n employee-api -l app=employee-api`
2. Check pod status: `kubectl get pods -n employee-api`
3. Check ingress: `kubectl describe ingress -n employee-api`
4. Review Cloud Build logs in GCP Console

---

**Project**: Employee API  
**Version**: 1.0.0  
**Last Updated**: 2025-11-21
