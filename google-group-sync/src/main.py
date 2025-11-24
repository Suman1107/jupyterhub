import os
import json
import requests
import google.auth
from googleapiclient.discovery import build
from google.cloud import secretmanager

# Configuration (environment variables)
API_ENDPOINT   = os.getenv("EMPLOYEE_API_URL")
TARGET_ROLES   = os.getenv("TARGET_ROLES", "roles/viewer")  # comma‑separated list of IAM roles
PROJECT_ID     = os.getenv("PROJECT_ID")

# Secret Manager client
secret_client = secretmanager.SecretManagerServiceClient()


def get_secret(secret_id: str, version: str = "latest") -> str:
    """Retrieve a secret from Google Cloud Secret Manager."""
    name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/{version}"
    response = secret_client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")


def get_oauth_token() -> str:
    """Generate OAuth2 token using client credentials from Secret Manager."""
    try:
        client_id = get_secret("employee-api-client-id")
        client_secret = get_secret("employee-api-client-secret")
        
        # Request token from Employee API
        token_url = f"{API_ENDPOINT}/api/token"
        response = requests.post(
            token_url,
            json={"client_id": client_id, "client_secret": client_secret},
            timeout=10
        )
        response.raise_for_status()
        token_data = response.json()
        return token_data["access_token"]
    except Exception as e:
        print(f"Error getting OAuth token: {str(e)}")
        raise


def fetch_employees_from_api():
    """Fetch employee list from the Employee API and return a set of IAM‑compatible members.
    Example return: {"user:alice@example.com", "user:bob@example.com"}
    """
    # Get OAuth2 token
    token = get_oauth_token()
    
    # Make authenticated request
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(f"{API_ENDPOINT}/api/employees", headers=headers, timeout=10)
    resp.raise_for_status()
    data = resp.json()
    # Filter out any placeholder/example addresses – only real Google accounts are allowed
    emails = {
        f"user:{emp['email'].lower()}"
        for emp in data.get("employees", [])
        if not emp['email'].lower().endswith("@example.com")
    }
    print(f"Fetched {len(emails)} valid employee members: {emails}")
    return emails

def get_iam_policy(svc, project_id):
    """Retrieve the current IAM policy for the given project."""
    return svc.projects().getIamPolicy(resource=project_id, body={}).execute()

def set_iam_policy(svc, project_id, policy):
    """Write the updated IAM policy back to the project."""
    return svc.projects().setIamPolicy(resource=project_id, body={"policy": policy}).execute()

def sync_role(svc, project_id, role, desired_members):
    """Synchronize a single IAM role to match *desired_members*.
    Returns a dict with the members that were added and removed for this role.
    """
    policy = get_iam_policy(svc, project_id)
    bindings = policy.get("bindings", [])

    # Locate existing binding for the role or create a fresh one
    target_binding = next((b for b in bindings if b["role"] == role), None)
    if not target_binding:
        target_binding = {"role": role, "members": []}
        bindings.append(target_binding)

    # Current members that are user:… (ignore service accounts, groups, etc.)
    current_members = {m.lower() for m in target_binding.get("members", []) if m.lower().startswith("user:")}
    to_add    = desired_members - current_members
    to_remove = current_members - desired_members

    print(f"Role {role}: adding {len(to_add)} members, removing {len(to_remove)} members")

    # Build the new member list while preserving non‑user members (service accounts, groups)
    new_members = [m for m in target_binding["members"] if not (m.lower().startswith("user:") and m.lower() in to_remove)]
    new_members.extend(to_add)
    target_binding["members"] = new_members
    policy["bindings"] = bindings

    # Apply the updated policy (atomic operation)
    set_iam_policy(svc, project_id, policy)
    return {"added": list(to_add), "removed": list(to_remove)}

def sync_iam(request):
    """Entry point for the Cloud Function (invoked by Cloud Scheduler)."""
    print(f"--- Starting IAM sync for project {PROJECT_ID} ---")
    if not all([API_ENDPOINT, PROJECT_ID]):
        return {"error": "Missing required environment variables"}, 500

    # Authenticate as the function's service account (Workload Identity)
    creds, _ = google.auth.default()
    iam_service = build("cloudresourcemanager", "v1", credentials=creds)

    # 1️⃣ Pull the source‑of‑truth employee list
    employee_members = fetch_employees_from_api()

    # 2️⃣ Parse the comma‑separated list of target roles
    roles = [r.strip() for r in TARGET_ROLES.split(',') if r.strip()]
    overall_result = {}
    for role in roles:
        result = sync_role(iam_service, PROJECT_ID, role, employee_members)
        overall_result[role] = result

    print("IAM sync completed for all roles")
    return json.dumps(overall_result), 200
