"""
Employee Management API
A FastAPI application for managing employee data with PostgreSQL backend
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import RealDictCursor
import os
import secrets
import hashlib
import jwt

# Configuration
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "jupyterhub_db")
DB_USER = os.getenv("DB_USER", "jupyter-user-sa@suman-110797.iam")
DB_PASSWORD = os.getenv("DB_PASSWORD", "ignored-by-proxy")

API_SECRET_KEY = os.getenv("API_SECRET_KEY", secrets.token_urlsafe(32))
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_urlsafe(32))
JWT_ALGORITHM = "HS256"

app = FastAPI(
    title="Employee Management API",
    description="Secure employee data management with PostgreSQL backend",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

# Pydantic Models
class UserSignup(BaseModel):
    username: str
    email: EmailStr
    password: str
    full_name: str

class UserLogin(BaseModel):
    username: str
    password: str

class Employee(BaseModel):
    employee_id: Optional[int] = None
    first_name: str
    last_name: str
    email: EmailStr
    department: str
    position: str
    salary: Optional[float] = None
    hire_date: Optional[datetime] = None

class APIKeyRequest(BaseModel):
    username: str

class APIKeyResponse(BaseModel):
    api_id: str
    api_secret: str
    created_at: datetime
    expires_at: datetime

# Database connection
def get_db():
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        sslmode='disable'
    )
    try:
        yield conn
    finally:
        conn.close()

# Initialize database tables
def init_db():
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        sslmode='disable'
    )
    cur = conn.cursor()
    
    # Users table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            user_id SERIAL PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            full_name VARCHAR(100),
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)
    
    # Employees table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS employees (
            employee_id SERIAL PRIMARY KEY,
            first_name VARCHAR(50) NOT NULL,
            last_name VARCHAR(50) NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            department VARCHAR(50),
            position VARCHAR(50),
            salary DECIMAL(10, 2),
            hire_date DATE DEFAULT CURRENT_DATE,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        )
    """)
    
    # API Keys table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS api_keys (
            key_id SERIAL PRIMARY KEY,
            user_id INTEGER REFERENCES users(user_id),
            api_id VARCHAR(64) UNIQUE NOT NULL,
            api_secret_hash VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            expires_at TIMESTAMP,
            is_active BOOLEAN DEFAULT TRUE
        )
    """)
    
    conn.commit()
    cur.close()
    conn.close()

# Helper functions
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(password: str, password_hash: str) -> bool:
    return hash_password(password) == password_hash

def create_jwt_token(data: dict, expires_delta: timedelta = timedelta(hours=24)):
    to_encode = data.copy()
    expire = datetime.utcnow() + expires_delta
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_jwt_token(token: str):
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify API key from Authorization header"""
    token = credentials.credentials
    
    # Check if it's a JWT token
    try:
        payload = verify_jwt_token(token)
        return payload
    except:
        pass
    
    # Check if it's an API key (format: api_id:api_secret)
    try:
        api_id, api_secret = token.split(":")
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT, database=DB_NAME,
            user=DB_USER, password=DB_PASSWORD, sslmode='disable'
        )
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT * FROM api_keys WHERE api_id = %s AND is_active = TRUE",
            (api_id,)
        )
        key = cur.fetchone()
        cur.close()
        conn.close()
        
        if key and verify_password(api_secret, key['api_secret_hash']):
            if key['expires_at'] and datetime.now() > key['expires_at']:
                raise HTTPException(status_code=401, detail="API key expired")
            return {"user_id": key['user_id'], "api_id": api_id}
        
        raise HTTPException(status_code=401, detail="Invalid API key")
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid authorization format")

# Routes
@app.on_event("startup")
async def startup_event():
    init_db()

@app.get("/")
async def root():
    return {
        "message": "Employee Management API",
        "version": "1.0.0",
        "endpoints": {
            "signup": "/auth/signup",
            "login": "/auth/login",
            "employees": "/api/employees",
            "api_key": "/auth/api-key"
        }
    }

@app.post("/auth/signup", status_code=status.HTTP_201_CREATED)
async def signup(user: UserSignup, conn=Depends(get_db)):
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # Check if user exists
    cur.execute("SELECT * FROM users WHERE username = %s OR email = %s", (user.username, user.email))
    if cur.fetchone():
        raise HTTPException(status_code=400, detail="Username or email already exists")
    
    # Create user
    password_hash = hash_password(user.password)
    cur.execute(
        "INSERT INTO users (username, email, password_hash, full_name) VALUES (%s, %s, %s, %s) RETURNING user_id",
        (user.username, user.email, password_hash, user.full_name)
    )
    user_id = cur.fetchone()['user_id']
    conn.commit()
    cur.close()
    
    return {"message": "User created successfully", "user_id": user_id}

@app.post("/auth/login")
async def login(user: UserLogin, conn=Depends(get_db)):
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT * FROM users WHERE username = %s", (user.username,))
    db_user = cur.fetchone()
    cur.close()
    
    if not db_user or not verify_password(user.password, db_user['password_hash']):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    token = create_jwt_token({"user_id": db_user['user_id'], "username": db_user['username']})
    return {"access_token": token, "token_type": "bearer"}

@app.post("/auth/api-key", response_model=APIKeyResponse)
async def create_api_key(request: APIKeyRequest, conn=Depends(get_db)):
    """Generate API key for a user"""
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # Get user
    cur.execute("SELECT user_id FROM users WHERE username = %s", (request.username,))
    user = cur.fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Generate API credentials
    api_id = secrets.token_urlsafe(16)
    api_secret = secrets.token_urlsafe(32)
    api_secret_hash = hash_password(api_secret)
    expires_at = datetime.now() + timedelta(days=365)
    
    # Store in database
    cur.execute(
        """INSERT INTO api_keys (user_id, api_id, api_secret_hash, expires_at) 
           VALUES (%s, %s, %s, %s) RETURNING created_at""",
        (user['user_id'], api_id, api_secret_hash, expires_at)
    )
    created_at = cur.fetchone()['created_at']
    conn.commit()
    cur.close()
    
    return APIKeyResponse(
        api_id=api_id,
        api_secret=api_secret,
        created_at=created_at,
        expires_at=expires_at
    )

@app.get("/api/employees", response_model=List[Employee])
async def get_employees(auth=Depends(verify_api_key), conn=Depends(get_db)):
    """Get all employees (requires authentication)"""
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT * FROM employees ORDER BY employee_id")
    employees = cur.fetchall()
    cur.close()
    return employees

@app.post("/api/employees", response_model=Employee, status_code=status.HTTP_201_CREATED)
async def create_employee(employee: Employee, auth=Depends(verify_api_key), conn=Depends(get_db)):
    """Create a new employee (requires authentication)"""
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(
        """INSERT INTO employees (first_name, last_name, email, department, position, salary, hire_date)
           VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING *""",
        (employee.first_name, employee.last_name, employee.email, 
         employee.department, employee.position, employee.salary, employee.hire_date)
    )
    new_employee = cur.fetchone()
    conn.commit()
    cur.close()
    return new_employee

@app.get("/api/employees/{employee_id}", response_model=Employee)
async def get_employee(employee_id: int, auth=Depends(verify_api_key), conn=Depends(get_db)):
    """Get employee by ID (requires authentication)"""
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT * FROM employees WHERE employee_id = %s", (employee_id,))
    employee = cur.fetchone()
    cur.close()
    
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
    return employee

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
