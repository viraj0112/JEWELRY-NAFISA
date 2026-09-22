"""API response schemas."""
from typing import TypeVar, Generic, Optional
from pydantic import BaseModel

T = TypeVar("T")

class ApiResponse(BaseModel, Generic[T]):
    """Standard API response wrapper."""
    success: bool
    data: Optional[T] = None
    error: Optional[str] = None
    message: Optional[str] = None

class ErrorResponse(BaseModel):
    """Error response."""
    success: bool = False
    error: str
    details: Optional[dict] = None
