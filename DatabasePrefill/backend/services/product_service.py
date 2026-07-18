"""Fill products workflow"""
from supabase import Client
from typing import List, Dict, Any, Optional
# from backend.services.llm_service import LLMService
from ..services.lm_service import LLMService
from backend.services.database_service import DatabaseService
from backend.services.processed_tracker import ProcessedTracker
from logging_config import get_logger

logger = get_logger(__name__)

# Shared across requests so the skip-list is consistent within a process.
_tracker = ProcessedTracker()

class ProductService:
    def __init__(self, supabase: Client, llm_api_key: str = None, llm_model: str = None):
        self.database_service = DatabaseService(supabase)
        # Per-request LLM credentials (resolved from the caller's x-api-key).
        self.llm_service = LLMService(llm_model=llm_model, api_key=llm_api_key)
        self.tracker = _tracker
    
    async def fill_single_product(
        self,
        product_id: int,
        table_name: str,
        image_url: str,
    ) -> Dict[str, Any]:
        """Fill empty product details from image using AI."""
        # Get existing product data
        product = self.database_service.get_product_by_id(table_name, product_id)
        if not product:
            raise ValueError(f"Product {product_id} not found in {table_name}")
        
        # Analyze image with LLM
        extracted_data = await self.llm_service.analyze_product_image(
            image_url=image_url,
            existing_data=product
        )
        
        # Update product with extracted data
        updates = self._extract_updates(extracted_data)
        self.database_service.update_product(
            table_name=table_name,
            product_id=product_id,
            updates=updates,
        )
        # Remember it so future runs never re-touch this row.
        self.tracker.mark(table_name, [product_id])

        # Shape matches ProductFillResponse.
        return {
            "product_id": product_id,
            "table_name": table_name,
            "filled_columns": list(updates.keys()),
            "image_url": image_url,
        }
    
    async def batch_fill(
        self,
        table_name: str,
        limit: int = 15,
        owner_id: str = None,
    ) -> Dict[str, Any]:
        """Fill products workflow. When `owner_id` is set, only that user's own
        rows are processed (used by b2b/manufacturer self-service fills)."""
        # Get empty products, skipping any we've already filled in a prior run.
        already_done = self.tracker.processed_ids(table_name)
        products = self.database_service.get_empty_product_columns(
            table_name, limit, exclude_ids=already_done, owner_id=owner_id
        )
        if not products:
            logger.info(f"No empty products found in {table_name}")
            return {"total": 0, "success": 0, "failed": 0,
                    "filled_ids": [], "details": []}

        # Pair each product with its image url, keeping the two in lockstep so
        # analysis results can never be attributed to the wrong product.
        details: List[Dict[str, Any]] = []
        candidates: List[Dict[str, Any]] = []   # products that have an image
        candidate_urls: List[str] = []
        failed_count = 0
        for product in products:
            image_url = self.database_service.get_image_url(product)
            if not image_url:
                failed_count += 1
                details.append({"id": product.get("id"), "status": "skipped",
                                "reason": "no image url"})
                continue
            candidates.append(product)
            candidate_urls.append(image_url)

        if not candidate_urls:
            logger.warning("No valid image URLs found for products")
            return {"total": len(products), "success": 0, "failed": failed_count,
                    "filled_ids": [], "details": details}

        # Analyze all images concurrently (bounded + retried inside the service).
        logger.info(f"Analyzing {len(candidate_urls)} images...")
        results = await self.llm_service.batch_analyze(candidate_urls)

        # Update products with extracted data — results[i] <-> candidates[i].
        filled_ids: List[int] = []
        for product, extracted_data in zip(candidates, results):
            product_id = product.get("id")

            # Skip if analysis failed
            if not isinstance(extracted_data, dict) or "error" in extracted_data:
                reason = extracted_data.get("error", "unknown") if isinstance(extracted_data, dict) else "no result"
                logger.warning(f"Failed to analyze product {product_id}: {reason}")
                failed_count += 1
                details.append({"id": product_id, "status": "failed", "reason": reason})
                continue

            # Update product with extracted data
            updates = self._extract_updates(extracted_data)
            try:
                self.database_service.update_product(
                    table_name=table_name,
                    product_id=product_id,
                    updates=updates,
                )
                filled_ids.append(product_id)
                details.append({"id": product_id, "status": "filled",
                                "columns": list(updates.keys())})
                logger.info(f"Successfully filled product {product_id}")
            except Exception as e:
                failed_count += 1
                details.append({"id": product_id, "status": "failed",
                                "reason": str(e)})
                logger.error(f"Error updating product {product_id}: {e}")

        # Persist the filled ids so they're never re-processed.
        if filled_ids:
            self.tracker.mark(table_name, filled_ids)

        return {
            "total": len(products),
            "success": len(filled_ids),
            "failed": failed_count,
            "filled_ids": filled_ids,
            "details": details,
        }
    
    # DB columns that are text[] arrays — a scalar value from the LLM is
    # wrapped in a list so the Postgres write doesn't fail on a type mismatch.
    _ARRAY_COLUMNS = {
        "Product Tags", "Stone Type", "Stone Used", "Stone Setting",
        "Stone Count", "Metal Color", "Stone Color", "Stone Cut", "Stone Quality",
        "Enamel Work", "Category", "Studded",
    }

    def _extract_updates(self, extracted_data: Dict[str, Any]) -> Dict[str, Any]:
        """Convert LLM output into a DB update dict keyed by REAL column names.

        Robust to either key convention the Gemini SDK might emit for a given
        field: the spaced alias ("Metal Color") or the Python field name
        ("Metal_Color"). We look up both, coerce array columns to lists, and
        drop empties so we never write a bad shape to Postgres.
        """
        # Real DB column name  ->  candidate keys the LLM output might use.
        column_keys = {
            "Description": ["Description"],
            "Product Tags": ["Product Tags", "Product_Tags"],
            "Metal Finish": ["Metal Finish", "Metal_Finish"],
            "Stone Type": ["Stone Type", "Stone_Type"],
            "Stone Used": ["Stone Used", "Stone_Used"],
            "Stone Setting": ["Stone Setting", "Stone_Setting"],
            "Stone Count": ["Stone Count", "Stone_Count"],
            "Metal Color": ["Metal Color", "Metal_Color"],
            "Stone Color": ["Stone Color", "Stone_Color"],
            "Stone Cut": ["Stone Cut", "Stone_Cut"],
            "Stone Quality": ["Stone Quality", "Stone_Quality"],
            "Enamel Work": ["Enamel Work", "Enamel_Work"],
            "Category": ["Category"],
            "Plain": ["Plain"],
            "Studded": ["Studded"],
            "Plating": ["Plating"],
        }

        updates: Dict[str, Any] = {}
        for column, keys in column_keys.items():
            value = next(
                (extracted_data[k] for k in keys if extracted_data.get(k) is not None),
                None,
            )
            if value is None:
                continue
            if column in self._ARRAY_COLUMNS and not isinstance(value, list):
                # Scalar slipped through for an array column — wrap it.
                value = [value] if str(value).strip() != "" else None
            if value is None or value == "" or value == []:
                continue
            updates[column] = value

        return updates