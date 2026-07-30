from supabase import Client
from typing import List, Dict, Optional, Any
from logging_config import get_logger

logger = get_logger(__name__)

from constants import TARGET_COLUMNS


def is_empty_value(value: Any) -> bool:
    """A column counts as empty — and therefore fillable — only when it is NULL,
    blank/whitespace, or an empty array.

    Anything else is data a human or an earlier fill already put there. This is
    the single definition of "empty" for the whole fill pipeline: the same test
    picks the candidate rows and decides which columns may be written, so a row
    can never be selected on one rule and overwritten on another.
    """
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip() == ""
    if isinstance(value, (list, tuple, dict, set)):
        return len(value) == 0
    return False


class DatabaseService:
    def __init__(self, client: Client):
        self.client = client
    
    def get_empty_product_columns(
        self,
        table_name: str,
        limit: int = 15,
        exclude_ids: Optional[set] = None,
        max_scan: int = 3000,
        owner_id: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """Return up to `limit` rows that (a) have at least one empty target
        column and (b) are NOT in `exclude_ids` (already processed).

        Filters client-side: PostgREST can't express a dynamic OR-across-many-
        columns "any is null/empty" predicate cleanly, so we page through rows
        ordered by id and filter in Python. Paging (rather than always fetching
        the newest window) means each run advances past rows we've already
        filled instead of re-scanning the same ones. `max_scan` caps the work.
        """
        exclude_ids = exclude_ids or set()
        products: List[Dict[str, Any]] = []
        page_size = 200
        offset = 0

        while len(products) < limit and offset < max_scan:
            query = self.client.table(table_name).select("*")
            if owner_id:
                query = query.eq("user_id", owner_id)  # own-row scoping
            response = (
                query
                .order("id", desc=False)
                .range(offset, offset + page_size - 1)
                .execute()
            )
            rows = response.data or []
            if not rows:
                break  # reached the end of the table

            for product in rows:
                if product.get("id") in exclude_ids:
                    continue
                has_empty = any(
                    is_empty_value(product.get(col)) for col in TARGET_COLUMNS
                )
                if has_empty:
                    products.append(product)
                    if len(products) >= limit:
                        break

            offset += page_size

        logger.info(f"Found {len(products)} products with empty columns in {table_name} "
                    f"(excluded {len(exclude_ids)} already-processed)")
        return products
    
    def get_product_by_id(self, table_name: str, product_id: int)->Optional[Dict[str, Any]]:
        try:
            response = (self.client.table(table_name)
            .select("*")
            .eq("id", product_id)
            .execute()
            ).data
            return response[0] if response else None
        except Exception as e:
            logger.error(f"Failed to fetch products {product_id}: {e}")
            raise
    
    def update_product(
        self,
        table_name: str,
        product_id: int,
        updates: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Update product with new data."""
        try:
            response = self.client.table(table_name).update(updates).eq("id", product_id).execute()
            logger.info(f"Updated product {product_id} in {table_name}")
            return response.data[0] if response.data else {}
        except Exception as e:
            logger.error(f"Error updating product {product_id}: {e}")
            raise

    def get_image_url(self, product: Dict[str, Any]) -> Optional[str]:
        """Extract image URL from product data."""
        # Check various image field formats
        images = product.get("Image") or product.get("Images") or product.get("image")

        if isinstance(images, list) and images:
            return images[0]
        elif isinstance(images, str):
            return images

        return None
    
    
