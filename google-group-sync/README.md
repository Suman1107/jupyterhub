# Google Group Sync Automation

This component automates the synchronization of employees from the Employee API (Component 2) to a Google Group in Google Workspace.

## Architecture

1.  **Cloud Function (Gen2)**: Python 3.11 function that:
    *   Fetches employee list from the Employee API.
    *   Fetches current members of the target Google Group.
    *   Calculates the difference (add/remove).
    *   Updates the Google Group using the Admin SDK Directory API.
2.  **Authentication**: Uses **Workload Identity** and **Domain-Wide Delegation** (DWD) without service account keys. It uses the IAM Credentials API to sign JWTs for DWD.
3.  **Cloud Scheduler**: Triggers the function hourly.

## Prerequisites

1.  **Google Workspace Account**: You must be a Super Admin to configure Domain-Wide Delegation.
2.  **GCP Project**: The project where Terraform will deploy resources.
3.  **Employee API**: Must be deployed and accessible (internal or external URL).

## Setup Instructions

### 1. Deploy Infrastructure with Terraform

Navigate to the `terraform` directory and apply the configuration:

```bash
cd terraform
terraform init
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="employee_api_url=http://YOUR_API_URL/api/employees" \
  -var="google_group_email=all-employees@yourdomain.com" \
  -var="delegated_admin_email=admin@yourdomain.com"
```

**Note the Outputs**:
After deployment, Terraform will output:
*   `service_account_email`: The email of the created Service Account.
*   `client_id`: The Unique ID (Client ID) of the Service Account. **You need this for Step 2.**

### 2. Configure Domain-Wide Delegation (CRITICAL)

This step must be done manually in the Google Admin Console by a Super Admin.

1.  Go to the **[Google Admin Console](https://admin.google.com/)**.
2.  Navigate to **Security > Access and data control > API controls**.
3.  Click **Manage Domain Wide Delegation** at the bottom.
4.  Click **Add new**.
5.  **Client ID**: Paste the `client_id` from the Terraform output.
6.  **OAuth Scopes**: Paste the following scope:
    ```
    https://www.googleapis.com/auth/admin.directory.group.member
    ```
7.  Click **Authorize**.

This grants the Service Account permission to act as a user (impersonation) to manage group members.

### 3. Verify

1.  Go to the GCP Console > Cloud Scheduler.
2.  Find `group-sync-job` and click **Force Run**.
3.  Check the logs of the `google-group-sync` Cloud Function to see the sync process in action.

## How It Works (Keyless DWD)

Standard Domain-Wide Delegation usually requires a Service Account JSON key file to sign JWTs. To avoid managing keys (security risk), this solution uses the **IAM Credentials API**:

1.  The Cloud Function authenticates as the Service Account using standard Google Cloud authentication (Metadata server).
2.  The code constructs a JWT claim set specifying the `sub` (subject) as the `delegated_admin_email`.
3.  It calls the `projects.serviceAccounts.signJwt` API method to sign this JWT using the Service Account's system-managed key.
4.  It exchanges this signed JWT for an OAuth 2.0 access token via `https://oauth2.googleapis.com/token`.
5.  This token is used to call the Admin SDK Directory API.

## Troubleshooting

*   **Error 401/403 "Not Authorized"**:
    *   Ensure you completed Step 2 (Domain-Wide Delegation) correctly with the correct Client ID and Scope.
    *   Ensure `delegated_admin_email` is a valid user in your Workspace who has permission to manage groups.
*   **Error "Service Account Token Creator"**:
    *   Ensure the Terraform applied successfully. The Service Account needs `roles/iam.serviceAccountTokenCreator` on *itself* to sign the JWT.
