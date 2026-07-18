"""Agent state definitions for LangGraph."""
from typing import TypedDict, Optional, List, Dict, Any

class ProductAnalysisState(TypedDict):
    """State for the product analysis agent."""
    product_id: int
    table_name: str
    image_url: str
    existing_data: Optional[Dict[str, Any]]
    extracted_data: Optional[Dict[str, Any]]
    confidence_scores: Optional[Dict[str, float]]
    updates: Optional[Dict[str, Any]]
    needs_review: bool
    errors: Optional[List[str]]
    result: Optional[Dict[str, Any]]

class ProductReviewState(TypedDict):
    """State for product review workflow."""
    product_id: int
    table_name: str
    suggested_values: Dict[str, Any]
    approved_values: Optional[Dict[str, Any]]
    rejected_values: Optional[List[str]]
    status: str  # pending, approved, rejected
    review_notes: Optional[str]
