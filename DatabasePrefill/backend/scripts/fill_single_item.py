"""Fill single product (oversite)"""

import supabase
import argparse
import sys
import asyncio # async calls
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent)) # two layer search

from supabase import create_client
from config import get_settings
from logging_config import setup_logging, get_logger
from services.product_service import ProductService

setup_logging()
logger = get_logger(__name__)

async def main():
    parser = argparse.ArgumentParser(description="Fill a single product details.")
    parser.add_argument("--table", required=True, help="Table name")
    parser.add_argument("--id", type=int, required=True, help="Product ID")
    parser.add_argument("--image", help="Image URL override")

    args = parser.parse_args()
    settings = get_settings()
    supabase = create_client(settings.database_url, settings.database_key)
    service = ProductService(supabase)
    try:
        result = await service.fill_single_product(
            product_id=args.id,
            table_name=args.table,
            image_url=args.image,
        )
        logger.info("Success! Filled columns: %s", result["filled_columns"])
        return 0
    except Exception as e:
        logger.error("Error filling product: %s", e)
        return 1

if __name__ == "__main__":
    sys.exit(asyncio.run(main()))

    