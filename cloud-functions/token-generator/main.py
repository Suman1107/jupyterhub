"""
Token Generator Cloud Function
Encrypts API credentials with KMS and generates a secure token
"""

import functions_framework
import json
import base64
from datetime import datetime, timedelta
from google.cloud import kms
import os

PROJECT_ID = os.getenv('GCP_PROJECT', 'suman-110797')
LOCATION = 'global'
KEY_RING = 'jupyterhub-keyring'
KEY_NAME = 'auth-token-key'

@functions_framework.http
def generate_token(request):
    """
    HTTP Cloud Function to generate encrypted tokens.
    
    Request JSON:
    {
        "api_id": "string",
        "api_secret": "string",
        "user_id": "string",
        "expiry_hours": 24 (optional)
    }
    
    Response JSON:
    {
        "token": "base64_encrypted_token",
        "expires_at": "ISO timestamp"
    }
    """
    
    # CORS headers
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    headers = {
        'Access-Control-Allow-Origin': '*'
    }
    
    try:
        # Parse request
        request_json = request.get_json(silent=True)
        if not request_json:
            return (json.dumps({'error': 'Invalid JSON'}), 400, headers)
        
        api_id = request_json.get('api_id')
        api_secret = request_json.get('api_secret')
        user_id = request_json.get('user_id')
        expiry_hours = request_json.get('expiry_hours', 24)
        
        if not all([api_id, api_secret, user_id]):
            return (json.dumps({'error': 'Missing required fields'}), 400, headers)
        
        # Calculate expiry
        expires_at = datetime.utcnow() + timedelta(hours=expiry_hours)
        
        # Create payload
        payload = {
            'api_id': api_id,
            'api_secret': api_secret,
            'user_id': user_id,
            'expires_at': expires_at.isoformat()
        }
        
        # Encrypt with KMS
        client = kms.KeyManagementServiceClient()
        key_name = client.crypto_key_path(PROJECT_ID, LOCATION, KEY_RING, KEY_NAME)
        
        plaintext = json.dumps(payload).encode('utf-8')
        encrypt_response = client.encrypt(
            request={'name': key_name, 'plaintext': plaintext}
        )
        
        # Encode as base64
        token = base64.b64encode(encrypt_response.ciphertext).decode('utf-8')
        
        response = {
            'token': token,
            'expires_at': expires_at.isoformat(),
            'user_id': user_id
        }
        
        return (json.dumps(response), 200, headers)
        
    except Exception as e:
        return (json.dumps({'error': str(e)}), 500, headers)
