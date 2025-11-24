"""FastAPI Employee Management Application."""
import os
import logging
from datetime import datetime
from contextlib import asynccontextmanager
from typing import List

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from database import init_db, get_db, Employee
from models import (
    EmployeeCreate,
    EmployeeResponse,
    EmployeeListResponse,
    MessageResponse,
    EmployeeCreatedResponse,
    HealthResponse
)
from auth import (
    create_access_token,
    verify_client_credentials,
    get_current_user,
    ACCESS_TOKEN_EXPIRE_MINUTES
)
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from datetime import timedelta


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenRequest(BaseModel):
    client_id: str
    client_secret: str

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    logger.info("Starting Employee API application")
    
    # Ensure data directory exists
    data_dir = os.path.dirname(os.getenv("DATABASE_PATH", "/app/data/employees.db"))
    os.makedirs(data_dir, exist_ok=True)
    logger.info(f"Data directory: {data_dir}")
    
    # Initialize database
    await init_db()
    logger.info("Database initialized")
    
    yield
    
    # Shutdown
    logger.info("Shutting down Employee API application")


# Create FastAPI app
app = FastAPI(
    title="Employee API",
    description="Production-ready employee management API",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# API Routes
@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Health check endpoint for Kubernetes probes."""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow()
    )


@app.post("/api/token", response_model=Token, tags=["Authentication"])
async def login(token_request: TokenRequest):
    """OAuth2 token endpoint using client credentials flow."""
    if not verify_client_credentials(token_request.client_id, token_request.client_secret):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid client credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": token_request.client_id},
        expires_delta=access_token_expires
    )
    
    logger.info(f"Token generated for client: {token_request.client_id}")
    return Token(access_token=access_token, token_type="bearer")


@app.get("/api/employees", response_model=EmployeeListResponse, tags=["Employees"])
async def get_employees(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Get list of all employees (requires authentication)."""
    try:
        result = await db.execute(select(Employee).order_by(Employee.created_at.desc()))
        employees = result.scalars().all()
        
        logger.info(f"Retrieved {len(employees)} employees")
        return EmployeeListResponse(
            employees=[EmployeeResponse.model_validate(emp) for emp in employees]
        )
    except Exception as e:
        logger.error(f"Error retrieving employees: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve employees"
        )


@app.post(
    "/api/employees",
    response_model=EmployeeCreatedResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Employees"]
)
async def create_employee(
    employee: EmployeeCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Add or update an employee (requires authentication)."""
    try:
        # Check if employee exists
        result = await db.execute(
            select(Employee).where(Employee.email == employee.email)
        )
        existing_employee = result.scalar_one_or_none()
        
        if existing_employee:
            # Update existing employee
            existing_employee.name = employee.name
            await db.commit()
            await db.refresh(existing_employee)
            
            logger.info(f"Updated employee: {employee.email}")
            return EmployeeCreatedResponse(
                message="Employee updated successfully",
                employee=EmployeeResponse.model_validate(existing_employee)
            )
        else:
            # Create new employee
            new_employee = Employee(
                name=employee.name,
                email=employee.email,
                created_at=datetime.utcnow()
            )
            db.add(new_employee)
            await db.commit()
            await db.refresh(new_employee)
            
            logger.info(f"Created employee: {employee.email}")
            return EmployeeCreatedResponse(
                message="Employee added successfully",
                employee=EmployeeResponse.model_validate(new_employee)
            )
    except Exception as e:
        await db.rollback()
        logger.error(f"Error creating/updating employee: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create/update employee"
        )


@app.delete("/api/employees/{email}", response_model=MessageResponse, tags=["Employees"])
async def delete_employee(
    email: str,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Remove an employee by email (requires authentication)."""
    try:
        # Check if employee exists
        result = await db.execute(
            select(Employee).where(Employee.email == email)
        )
        employee = result.scalar_one_or_none()
        
        if not employee:
            logger.warning(f"Employee not found: {email}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Employee not found"
            )
        
        # Delete employee
        await db.execute(
            delete(Employee).where(Employee.email == email)
        )
        await db.commit()
        
        logger.info(f"Deleted employee: {email}")
        return MessageResponse(message="Employee deleted successfully")
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Error deleting employee: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete employee"
        )


# Mount static files and serve frontend
app.mount("/static", StaticFiles(directory="/app/static"), name="static")


@app.get("/", tags=["Frontend"])
async def serve_frontend():
    """Serve the frontend HTML."""
    return FileResponse("/app/static/index.html")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        log_level=os.getenv("LOG_LEVEL", "info").lower()
    )
