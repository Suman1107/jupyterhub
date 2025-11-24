# 📦 Employee API - Deployment Checklist

## ✅ Pre-Deployment Verification

### Files Created (28 total)
- [x] README.md (8,827 bytes)
- [x] QUICKSTART.md (7,095 bytes)
- [x] ARCHITECTURE.md (16,874 bytes)
- [x] PROJECT_SUMMARY.md (11,125 bytes)
- [x] Dockerfile (1,332 bytes)
- [x] .dockerignore (421 bytes)
- [x] .gitignore (718 bytes)
- [x] deploy.sh (3,414 bytes, executable)
- [x] cloudbuild.yaml (4,670 bytes)

### Backend Files (4)
- [x] app/main.py (209 lines)
- [x] app/database.py (56 lines)
- [x] app/models.py (44 lines)
- [x] app/requirements.txt (6 lines)

### Frontend Files (2)
- [x] static/index.html (475 lines)
- [x] static/js/app.js (204 lines)

### Kubernetes Manifests (6)
- [x] k8s/namespace.yaml (8 lines)
- [x] k8s/pvc.yaml (14 lines)
- [x] k8s/deployment.yaml (75 lines)
- [x] k8s/service.yaml (17 lines)
- [x] k8s/ingress.yaml (24 lines)
- [x] k8s/hpa.yaml (44 lines)

### Terraform Files (7)
- [x] terraform/main.tf (16 lines)
- [x] terraform/variables.tf (59 lines)
- [x] terraform/outputs.tf (39 lines)
- [x] terraform/provider.tf (36 lines)
- [x] terraform/kubernetes.tf (294 lines)
- [x] terraform/artifact_registry.tf (33 lines)
- [x] terraform/cloudbuild.tf (62 lines)

### Total Lines of Code: 1,886 lines

---

## 🚀 Deployment Options

### Option A: Automated Deployment (Fastest)
```bash
cd /Users/sumanmoharana/Desktop/suman/project/JupyterHub/employee-api-app
./deploy.sh
```
**Time**: ~10-15 minutes  
**Difficulty**: Easy  
**Best for**: Quick deployment

### Option B: Manual Terraform + Cloud Build
```bash
# Step 1: Deploy infrastructure (2-3 minutes)
cd terraform
terraform init
terraform apply -auto-approve \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"

# Step 2: Build and deploy (5-10 minutes)
cd ..
gcloud builds submit --config=cloudbuild.yaml

# Step 3: Verify
kubectl get all -n employee-api
kubectl get ingress -n employee-api
```
**Time**: ~10-15 minutes  
**Difficulty**: Medium  
**Best for**: Understanding the process

### Option C: Local Testing First
```bash
# Test locally before deploying
docker build -t employee-api:local .
docker run -p 8080:8080 -v $(pwd)/data:/app/data employee-api:local

# Open http://localhost:8080
# Then deploy using Option A or B
```
**Time**: ~15-20 minutes  
**Difficulty**: Easy  
**Best for**: Development and testing

---

## 📋 Pre-Deployment Checklist

### GCP Prerequisites
- [ ] `gcloud` CLI installed and authenticated
- [ ] Active GCP project: `suman-110797`
- [ ] GKE cluster running: `jupyterhub-cluster` in `us-central1-a`
- [ ] NGINX Ingress Controller installed on cluster
- [ ] Sufficient GCP quotas (CPU, memory, disk)

### Local Prerequisites
- [ ] Docker installed and running
- [ ] `kubectl` installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Terminal access to project directory

### Permissions Required
- [ ] Artifact Registry Admin (to create repository)
- [ ] Cloud Build Editor (to create triggers)
- [ ] Kubernetes Engine Developer (to deploy to GKE)
- [ ] Service Account User (for Cloud Build)

### Verify Prerequisites
```bash
# Check gcloud
gcloud --version
gcloud config get-value project  # Should show: suman-110797

# Check kubectl
kubectl version --client
kubectl config current-context  # Should show your GKE cluster

# Check terraform
terraform --version  # Should be >= 1.0

# Check Docker
docker --version
docker ps  # Should not error

# Check cluster access
kubectl get nodes  # Should show cluster nodes
```

---

## 🎯 Deployment Steps (Detailed)

### Step 1: Navigate to Project
```bash
cd /Users/sumanmoharana/Desktop/suman/project/JupyterHub/employee-api-app
```

### Step 2: Review Configuration (Optional)
```bash
# Review Terraform variables
cat terraform/variables.tf

# Review Kubernetes manifests
ls -l k8s/

# Review Cloud Build config
cat cloudbuild.yaml
```

### Step 3: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"

# Review the plan, then apply
terraform apply \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"
```

**Expected Output**:
- Artifact Registry repository created
- Cloud Build trigger created
- Kubernetes namespace created
- All K8s resources created
- IAM permissions configured

### Step 4: Build and Deploy Application
```bash
cd ..
gcloud container clusters get-credentials jupyterhub-cluster \
  --zone=us-central1-a \
  --project=suman-110797

gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=_IMAGE_TAG=v1.0.0 \
  --project=suman-110797
```

**Expected Output**:
- Docker image built
- Image pushed to Artifact Registry
- Kubernetes resources deployed
- Deployment rolled out
- Pods running

### Step 5: Verify Deployment
```bash
# Check namespace
kubectl get namespace employee-api

# Check all resources
kubectl get all -n employee-api

# Check pods are running
kubectl get pods -n employee-api
# Expected: 2 pods in Running status

# Check ingress
kubectl get ingress -n employee-api
# Expected: Ingress with external IP

# Check HPA
kubectl get hpa -n employee-api
# Expected: HPA with 2/2 replicas
```

### Step 6: Test the Application
```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get ingress -n employee-api employee-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# Test health endpoint
curl http://$INGRESS_IP/health

# Test API
curl http://$INGRESS_IP/api/employees

# Open in browser
open http://$INGRESS_IP
```

---

## 🔍 Post-Deployment Verification

### Check 1: Pods Running
```bash
kubectl get pods -n employee-api
```
**Expected**: 2 pods with status `Running`

### Check 2: Service Accessible
```bash
kubectl get svc -n employee-api
```
**Expected**: Service with ClusterIP

### Check 3: Ingress Working
```bash
kubectl get ingress -n employee-api
```
**Expected**: Ingress with external IP assigned

### Check 4: HPA Active
```bash
kubectl get hpa -n employee-api
```
**Expected**: HPA showing current/desired replicas

### Check 5: Logs Clean
```bash
kubectl logs -n employee-api -l app=employee-api --tail=20
```
**Expected**: No error messages, application started successfully

### Check 6: Health Check
```bash
INGRESS_IP=$(kubectl get ingress -n employee-api employee-api-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$INGRESS_IP/health
```
**Expected**: `{"status":"healthy","timestamp":"..."}`

### Check 7: API Working
```bash
# Add an employee
curl -X POST http://$INGRESS_IP/api/employees \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'

# Get employees
curl http://$INGRESS_IP/api/employees

# Delete employee
curl -X DELETE http://$INGRESS_IP/api/employees/test@example.com
```
**Expected**: Successful responses with proper JSON

---

## 📊 Monitoring Commands

### Real-time Logs
```bash
kubectl logs -n employee-api -l app=employee-api -f
```

### Pod Status
```bash
watch kubectl get pods -n employee-api
```

### Resource Usage
```bash
kubectl top pods -n employee-api
```

### Events
```bash
kubectl get events -n employee-api --sort-by='.lastTimestamp'
```

### Describe Deployment
```bash
kubectl describe deployment -n employee-api employee-api
```

---

## 🐛 Troubleshooting Quick Reference

### Issue: Pods not starting
```bash
kubectl describe pod -n employee-api <pod-name>
kubectl logs -n employee-api <pod-name>
```

### Issue: Ingress no IP
```bash
kubectl describe ingress -n employee-api employee-api-ingress
kubectl get svc -n ingress-nginx  # Check NGINX controller
```

### Issue: Image pull error
```bash
# Check Artifact Registry
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/suman-110797/employee-api

# Check IAM permissions
gcloud artifacts repositories get-iam-policy employee-api \
  --location=us-central1
```

### Issue: Database not persisting
```bash
kubectl get pvc -n employee-api
kubectl describe pvc -n employee-api employee-api-data
```

---

## 🔄 Update/Redeploy

### Update Application Code
```bash
# Make changes to code
# Then rebuild and deploy
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=_IMAGE_TAG=v1.1.0
```

### Update Kubernetes Resources
```bash
# Edit k8s/*.yaml files
# Then apply
kubectl apply -f k8s/
```

### Update Terraform
```bash
cd terraform
# Edit .tf files
terraform plan
terraform apply
```

---

## 🧹 Cleanup

### Remove Application Only
```bash
kubectl delete namespace employee-api
```

### Remove Everything (Including Infrastructure)
```bash
cd terraform
terraform destroy \
  -var="project_id=suman-110797" \
  -var="region=us-central1" \
  -var="cluster_name=jupyterhub-cluster" \
  -var="cluster_location=us-central1-a"
```

---

## 📞 Support Resources

### Documentation
- [README.md](README.md) - Complete documentation
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview

### Logs and Monitoring
```bash
# Application logs
kubectl logs -n employee-api -l app=employee-api

# Cloud Build logs
gcloud builds list --project=suman-110797

# GCP Console
# https://console.cloud.google.com/kubernetes/workload?project=suman-110797
```

---

## ✅ Success Indicators

After successful deployment, you should see:

1. ✅ 2 pods running in `employee-api` namespace
2. ✅ Ingress with external IP assigned
3. ✅ Health endpoint returning `{"status":"healthy"}`
4. ✅ UI accessible at `http://<INGRESS_IP>`
5. ✅ API endpoints working (GET, POST, DELETE)
6. ✅ HPA showing 2/2 replicas
7. ✅ No error logs in pods
8. ✅ PVC bound and mounted

---

## 🎉 You're Ready!

Everything is prepared and ready for deployment. Choose your method and deploy!

**Recommended**: Start with Option C (local testing) if this is your first time, then proceed with Option A (automated deployment).

---

**Last Updated**: 2025-11-21  
**Version**: 1.0.0  
**Status**: ✅ Ready for Production
