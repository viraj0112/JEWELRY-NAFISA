"""Product-related Pydantic schemas."""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field

class ProductFillRequest(BaseModel):
    """Request to fill a single product."""
    product_id: int = Field(..., description="Product ID in the database")
    table_name: str = Field(..., description="Table name: products, designerproducts, or manufacturerproducts")
    image_url: Optional[str] = Field(None, description="Image URL override")

class ProductFillResponse(BaseModel):
    """Response for single product fill."""
    product_id: int
    table_name: str
    filled_columns: List[str]
    image_url: str

class BatchFillRequest(BaseModel):
    """Request to fill multiple products."""
    table_name: str = Field(..., description="Table name to process")
    limit: int = Field(20, ge=1, le=100, description="Number of products to process")

class BatchFillResponse(BaseModel):
    """Response for batch fill operation."""
    total: int
    success: int
    failed: int
    filled_ids: List[int] = Field(default_factory=list,
                                  description="IDs of rows written to the DB")
    details: List[Dict[str, Any]] = Field(default_factory=list)

class PendingProduct(BaseModel):
    """Product pending review."""
    id: int
    product_title: Optional[str] = None
    image: Optional[str] = None
    empty_columns: List[str] = Field(default_factory=list)
