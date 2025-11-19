"""
Secure API Token Consumer for JupyterHub
Decrypts KMS-encrypted tokens and uses them to call the Employee API
"""

import base64
import json
import os
from datetime import datetime
from google.cloud import kms
import requests

# Configuration
PROJECT_ID = os.getenv('GCP_PROJECT_ID', 'suman-110797')
LOCATION = 'global'
KEY_RING = 'jupyterhub-keyring'
KEY_NAME = 'auth-token-key'
API_BASE_URL = os.getenv('API_BASE_URL', 'http://employee-api.jhub.svc.cluster.local')

class SecureAPIClient:
    """
    Client for accessing the Employee API using KMS-encrypted tokens
    """
    
    def __init__(self, encrypted_token: str):
        """
        Initialize with an encrypted token
        
        Args:
            encrypted_token: Base64-encoded KMS-encrypted token
        """
        self.encrypted_token = encrypted_token
        self._credentials = None
        self._decrypt_token()
    
    def _decrypt_token(self):
        """Decrypt the token using Cloud KMS"""
        try:
            # Decode base64
            ciphertext = base64.b64decode(self.encrypted_token)
            
            # Decrypt with KMS
            client = kms.KeyManagementServiceClient()
            key_name = client.crypto_key_path(PROJECT_ID, LOCATION, KEY_RING, KEY_NAME)
            
            decrypt_response = client.decrypt(
                request={'name': key_name, 'ciphertext': ciphertext}
            )
            
            # Parse decrypted payload
            payload = json.loads(decrypt_response.plaintext.decode('utf-8'))
            
            # Check expiry
            expires_at = datetime.fromisoformat(payload['expires_at'])
            if datetime.utcnow() > expires_at:
                raise ValueError(f"Token expired at {expires_at}")
            
            self._credentials = payload
            print(f"✅ Token decrypted successfully")
            print(f"   User ID: {payload['user_id']}")
            print(f"   Expires: {expires_at}")
            
        except Exception as e:
            raise ValueError(f"Failed to decrypt token: {str(e)}")
    
    def _get_auth_header(self):
        """Get authorization header"""
        api_id = self._credentials['api_id']
        api_secret = self._credentials['api_secret']
        return f"{api_id}:{api_secret}"
    
    def get_employees(self):
        """Fetch all employees from the API"""
        url = f"{API_BASE_URL}/api/employees"
        headers = {
            'Authorization': f'Bearer {self._get_auth_header()}'
        }
        
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    
    def get_employee(self, employee_id: int):
        """Fetch a specific employee by ID"""
        url = f"{API_BASE_URL}/api/employees/{employee_id}"
        headers = {
            'Authorization': f'Bearer {self._get_auth_header()}'
        }
        
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()
    
    def create_employee(self, employee_data: dict):
        """Create a new employee"""
        url = f"{API_BASE_URL}/api/employees"
        headers = {
            'Authorization': f'Bearer {self._get_auth_header()}',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(url, headers=headers, json=employee_data)
        response.raise_for_status()
        return response.json()


def test_api_access(encrypted_token: str):
    """
    Test function to demonstrate API access
    
    Usage in JupyterHub notebook:
        from api_consumer import test_api_access
        
        # Your encrypted token from the token generator
        token = "YOUR_ENCRYPTED_TOKEN_HERE"
        test_api_access(token)
    """
    print("=" * 60)
    print("Testing Secure API Access")
    print("=" * 60)
    print()
    
    try:
        # Initialize client
        client = SecureAPIClient(encrypted_token)
        
        # Fetch employees
        print("\n📊 Fetching employees...")
        employees = client.get_employees()
        print(f"✅ Retrieved {len(employees)} employees")
        
        if employees:
            print("\nFirst employee:")
            emp = employees[0]
            print(f"  ID: {emp.get('employee_id')}")
            print(f"  Name: {emp.get('first_name')} {emp.get('last_name')}")
            print(f"  Department: {emp.get('department')}")
            print(f"  Position: {emp.get('position')}")
        
        print("\n" + "=" * 60)
        print("✅ API access test successful!")
        print("=" * 60)
        
        return client
        
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        raise


# Example usage
if __name__ == "__main__":
    print("""
    Secure API Token Consumer
    
    Usage:
    1. Get your encrypted token from the token generator
    2. Use it to create a client:
    
        from api_consumer import SecureAPIClient
        
        token = "YOUR_ENCRYPTED_TOKEN"
        client = SecureAPIClient(token)
        
        # Fetch employees
        employees = client.get_employees()
        
        # Get specific employee
        emp = client.get_employee(1)
        
        # Create new employee
        new_emp = client.create_employee({
            "first_name": "John",
            "last_name": "Doe",
            "email": "john.doe@example.com",
            "department": "Engineering",
            "position": "Software Engineer",
            "salary": 75000
        })
    """)
