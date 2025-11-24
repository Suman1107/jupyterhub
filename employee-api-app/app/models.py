"""Pydantic models for request/response validation."""
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import List, Optional


class EmployeeBase(BaseModel):
    """Base employee model."""
    name: str = Field(..., min_length=1, max_length=100, description="Employee name")
    email: EmailStr = Field(..., description="Employee email address")


class EmployeeCreate(EmployeeBase):
    """Model for creating an employee."""
    pass


class EmployeeResponse(EmployeeBase):
    """Model for employee response."""
    created_at: datetime = Field(..., description="Timestamp when employee was created")

    class Config:
        from_attributes = True


class EmployeeListResponse(BaseModel):
    """Model for list of employees response."""
    employees: List[EmployeeResponse]


class MessageResponse(BaseModel):
    """Generic message response."""
    message: str


class EmployeeCreatedResponse(MessageResponse):
    """Response after creating an employee."""
    employee: EmployeeResponse


class HealthResponse(BaseModel):
    """Health check response."""
    status: str = "healthy"
    timestamp: datetime
