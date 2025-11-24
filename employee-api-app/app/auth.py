"""OAuth2 authentication for Employee API."""
import os
import logging
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from google.cloud import secretmanager

logger = logging.getLogger(__name__)

# OAuth2 configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/token", auto_error=False)

# Secret Manager client
secret_client = None


def get_secret_manager_client():
    """Get or create Secret Manager client."""
    global secret_client
    if secret_client is None:
        secret_client = secretmanager.SecretManagerServiceClient()
    return secret_client


def get_secret(project_id: str, secret_id: str, version: str = "latest") -> str:
    """Retrieve a secret from Google Cloud Secret Manager."""
    try:
        client = get_secret_manager_client()
        name = f"projects/{project_id}/secrets/{secret_id}/versions/{version}"
        response = client.access_secret_version(request={"name": name})
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logger.error(f"Error retrieving secret {secret_id}: {str(e)}")
        raise


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def verify_token(token: str) -> dict:
    """Verify and decode a JWT token."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError as e:
        logger.warning(f"Token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Dependency to get the current authenticated user from token."""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    payload = verify_token(token)
    client_id: str = payload.get("sub")
    if client_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return {"client_id": client_id}


def verify_client_credentials(client_id: str, client_secret: str) -> bool:
    """Verify client credentials against Secret Manager."""
    try:
        project_id = os.getenv("GCP_PROJECT_ID")
        if not project_id:
            logger.error("GCP_PROJECT_ID not set")
            return False
        
        # Retrieve stored credentials from Secret Manager
        stored_client_id = get_secret(project_id, "employee-api-client-id")
        stored_client_secret = get_secret(project_id, "employee-api-client-secret")
        
        return client_id == stored_client_id and client_secret == stored_client_secret
    except Exception as e:
        logger.error(f"Error verifying credentials: {str(e)}")
        return False
