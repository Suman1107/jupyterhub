import os
import json
import requests
import google.auth
from googleapiclient.discovery import build

# -------------------------------------------------
# Configuration (environment variables)
# -------------------------------------------------
API_ENDPOINT   = os.getenv("EMPLOYEE_API_URL")
DEFAULT_ROLES  = os.getenv("TARGET_ROLES", "roles/viewer")  # fallback comma‑separated list
PROJECT_ID     = os.getenv("PROJECT_ID")
PRESERVE_EXTRAS = os.getenv("PRESERVE_EXTRAS", "false").lower() == "true"

def fetch_employees_from_api():
    """Fetch employee list from the Employee API.
    Expected JSON format:
    {
        "employees": [
            {"email": "alice@example.com", "roles": ["roles/viewer", "roles/storage.objectViewer"]},
            {"email": "bob@example.com"}  # will receive DEFAULT_ROLES
        ]
    }
    Returns a dict mapping each IAM role to a set of "user:email" members.
    """
    resp = requests.get(f"{API_ENDPOINT}/api/employees", timeout=10)
    resp.raise_for_status()
    data = resp.json()

    role_to_members = {}
    for emp in data.get("employees", []):
        email = emp.get("email", "").lower()
        if not email or email.endswith("@example.com"):
            # skip placeholder/test addresses
            continue
        member = f"user:{email}"
        emp_roles = emp.get("roles")
        if not emp_roles:
            # Use default roles if none specified for this employee
            emp_roles = [r.strip() for r in DEFAULT_ROLES.split(',') if r.strip()]
        for role in emp_roles:
            role = role.strip()
            if not role:
                continue
            role_to_members.setdefault(role, set()).add(member)
    print(f"Fetched role mapping from API: {role_to_members}")
    return role_to_members

def get_iam_policy(svc, project_id):
    return svc.projects().getIamPolicy(resource=project_id, body={}).execute()

def set_iam_policy(svc, project_id, policy):
    return svc.projects().setIamPolicy(resource=project_id, body={"policy": policy}).execute()

def sync_role(svc, project_id, role, desired_members):
    """Synchronize a single IAM role.
    *desired_members* is a set of "user:email" strings that should be bound to *role*.
    Returns a dict with added and removed members.
    """
    policy = get_iam_policy(svc, project_id)
    bindings = policy.get("bindings", [])

    # Find existing binding for the role or create a new one
    target_binding = next((b for b in bindings if b["role"] == role), None)
    if not target_binding:
        target_binding = {"role": role, "members": []}
        bindings.append(target_binding)

    # Current user members (ignore service accounts, groups, etc.)
    current_members = {m.lower() for m in target_binding.get("members", []) if m.lower().startswith("user:")}
    to_add    = desired_members - current_members
    to_remove = set() if PRESERVE_EXTRAS else (current_members - desired_members)

    print(f"Role {role}: +{len(to_add)} -{len(to_remove)}")

    # Build new member list: keep existing non‑user members, add new users, optionally remove stale ones
    new_members = [m for m in target_binding["members"] if not (m.lower().startswith("user:") and m.lower() in to_remove)]
    new_members.extend(to_add)
    # Deduplicate just in case
    target_binding["members"] = list(set(new_members))
    policy["bindings"] = bindings

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

    # 1️⃣ Pull role → members mapping from the API
    role_to_members = fetch_employees_from_api()

    # 2️⃣ Ensure default roles are present even if no employee explicitly requests them
    for role in [r.strip() for r in DEFAULT_ROLES.split(',') if r.strip()]:
        role_to_members.setdefault(role, set())

    overall_result = {}
    for role, members in role_to_members.items():
        result = sync_role(iam_service, PROJECT_ID, role, members)
        overall_result[role] = result

    print("IAM sync completed for all roles")
    return json.dumps(overall_result), 200
