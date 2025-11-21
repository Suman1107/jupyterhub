# Citadel IAM Sync

A minimal, production‑ready package that syncs employee email addresses from an **Employee API** to one or more IAM roles on a GCP project. It consists of:

- **Cloud Function (Gen2)** – Python code that fetches employees, iterates over the roles you specify, and updates the IAM policy.
- **Cloud Scheduler** – Triggers the function on a configurable schedule (default hourly).
- **Terraform** – Deploys the service account, IAM admin binding, function, and scheduler.

---

## Folder layout
```
citadel_iam_sync/
├─ src/                 # Cloud Function source code
│   └─ main.py
├─ terraform/           # All Terraform resources
│   ├─ main.tf          # Provider & required APIs
│   ├─ variables.tf     # Input variables
│   ├─ iam.tf           # Service account + Project IAM Admin role
│   ├─ cloudfunction.tf # Cloud Function definition
│   └─ scheduler.tf     # Cloud Scheduler job
└─ README.md            # This file
```

---

## Prerequisites
1. **Google Cloud SDK** (`gcloud`) installed and authenticated.
2. **Terraform** (v1.0+).
3. An **Employee API** that returns JSON in the form:
   ```json
   {"employees": [{"email": "alice@example.com"}, {"email": "bob@example.com"}]}
   ```
   The API must be reachable from the Cloud Function.
4. The project where you will deploy must have the following APIs enabled (Terraform will enable them for you):
   - `cloudfunctions.googleapis.com`
   - `run.googleapis.com`
   - `cloudbuild.googleapis.com`
   - `artifactregistry.googleapis.com`
   - `cloudscheduler.googleapis.com`
   - `iamcredentials.googleapis.com`
   - `cloudresourcemanager.googleapis.com`

---

## Deployment steps
1. **Clone / copy the folder** to your workstation.
   ```bash
   git clone <repo‑url>   # or copy the directory manually
   cd citadel_iam_sync
   ```

2. **Initialize Terraform** (only needed once).
   ```bash
   terraform init
   ```

3. **Create a `terraform.tfvars` file** (or pass variables on the CLI) with your project‑specific values:
   ```hcl
   project_id        = "my-gcp-project"
   employee_api_url  = "http://<your‑api-host>/api"
   target_roles      = "roles/viewer,roles/storage.objectViewer,roles/compute.osLogin"
   schedule_cron     = "0 * * * *"   # hourly – adjust as needed
   ```

4. **Apply the Terraform configuration**.
   ```bash
   terraform apply -auto-approve
   ```
   Terraform will:
   - Create a service account `group-sync-sa` with `Project IAM Admin` role.
   - Package `src/main.py` into a zip and upload it to a bucket.
   - Deploy the Cloud Function (`citadel-iam-sync`).
   - Create a Cloud Scheduler job that POSTs to the function on the schedule.

5. **Verify the deployment**.
   - Check the function URL:
     ```bash
     terraform output function_uri
     ```
   - Manually trigger the function (optional):
     ```bash
     gcloud functions call citadel-iam-sync --gen2 --region=us-central1 --format=json
     ```
   - Inspect IAM bindings to confirm the employee emails were added:
     ```bash
     gcloud projects get-iam-policy $PROJECT_ID \
       --flatten="bindings[].members" \
       --format="table(bindings.role, bindings.members)" \
       --filter="bindings.role:roles/*"
     ```

6. **Update the employee list** – The function reads the API each run, so any change in the API is reflected automatically on the next scheduler execution.

---

## Customisation
- **Add/remove roles** – modify `target_roles` (comma‑separated) and re‑apply.
- **Change schedule** – edit `schedule_cron` (cron syntax) and re‑apply.
- **Filtering** – The function already filters out any email ending with `@example.com`. Adjust the filter in `src/main.py` if you need different validation.

---

## Cleanup
To destroy all resources:
```bash
terraform destroy -auto-approve
```
This will remove the Cloud Function, Scheduler job, service account, and the temporary storage bucket.

---

Enjoy a lightweight, reusable IAM sync solution! 🎉
