"""API routes for product filling."""
from typing import List
from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import StreamingResponse
from backend.routes.deps import SupabaseClient, VerifiedAPIKey, Auth
from backend.schemas.products import (
    ProductFillRequest,
    ProductFillResponse,
    BatchFillRequest,
    BatchFillResponse,
    PendingProduct,
)
from backend.schemas.response import ApiResponse, ErrorResponse
from backend.services.product_service import ProductService
from logging_config import get_logger

logger = get_logger(__name__)
router = APIRouter()

@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "Database Prefill"}

@router.post("/fill-product", response_model=ApiResponse[ProductFillResponse])
async def fill_product(
    request: ProductFillRequest,
    supabase: SupabaseClient,
    api_key: VerifiedAPIKey,
):
    """Fill empty product details from image using AI."""
    try:
        service = ProductService(supabase)
        result = await service.fill_single_product(
            product_id=request.product_id,
            table_name=request.table_name,
            image_url=request.image_url,
        )
        return ApiResponse(
            success=True,
            data=ProductFillResponse(**result)
        )
    except Exception as e:
        logger.error(f"Error filling product: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/batch-fill", response_model=ApiResponse[BatchFillResponse])
async def batch_fill(
    request: BatchFillRequest,
    supabase: SupabaseClient,
    api_key: VerifiedAPIKey,
):
    """Batch fill empty product details."""
    try:
        service = ProductService(supabase)
        result = await service.batch_fill(
            table_name=request.table_name,
            limit=request.limit,
        )
        return ApiResponse(
            success=True,
            data=BatchFillResponse(**result)
        )
    except Exception as e:
        logger.error(f"Error in batch fill: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/process-csv")
async def process_csv(
    api_key: VerifiedAPIKey,
    file: UploadFile = File(...),
):
    """Process an uploaded CSV file, fill missing columns, and return updated CSV."""
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="File must be a CSV")

    try:
        from backend.services.csv_service import CsvService
        content = await file.read()
        csv_string = content.decode("utf-8")
        
        service = CsvService()
        updated_csv = await service.process_csv(csv_string)
        
        import io
        
        return StreamingResponse(
            io.StringIO(updated_csv),
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename=updated_{file.filename}"
            }
        )
    except Exception as e:
        logger.error(f"Error processing CSV: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/process-database-fill", response_model=ApiResponse[BatchFillResponse])
async def process_database_fill(
    request: BatchFillRequest,
    supabase: SupabaseClient,
    auth: Auth,
):
    """ADMIN: fill rows with missing target columns in any table, using the
    resolved LLM credentials. Returns the written row IDs (`data.filled_ids`)."""
    if not auth.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    logger.info(f"[admin] database fill: table={request.table_name} limit={request.limit}")
    try:
        service = ProductService(
            supabase, llm_api_key=auth.llm_api_key, llm_model=auth.llm_model
        )
        result = await service.batch_fill(
            table_name=request.table_name,
            limit=request.limit,
        )
        return ApiResponse(success=True, data=BatchFillResponse(**result))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in database fill: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fill-my-products", response_model=ApiResponse[BatchFillResponse])
async def fill_my_products(
    request: BatchFillRequest,
    supabase: SupabaseClient,
    auth: Auth,
):
    """B2B/MANUFACTURER: fill only the caller's OWN product rows. The table is
    derived from the caller's role; the `table_name` in the body is ignored."""
    table_name = auth.own_table
    if not table_name:
        raise HTTPException(
            status_code=403,
            detail="Only designer or manufacturer accounts can fill their own products",
        )
    logger.info(f"[user {auth.user_id}] fill own products: table={table_name} limit={request.limit}")
    try:
        service = ProductService(
            supabase, llm_api_key=auth.llm_api_key, llm_model=auth.llm_model
        )
        result = await service.batch_fill(
            table_name=table_name,
            limit=request.limit,
            owner_id=auth.user_id,
        )
        return ApiResponse(success=True, data=BatchFillResponse(**result))
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in fill-my-products: {e}")
        raise HTTPException(status_code=500, detail=str(e))
