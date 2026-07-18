"""Fill batch items (oversite)"""
#!/usr/bin/env python3
"""Batch fill script - standalone CLI for filling empty product columns."""
import argparse
import asyncio
import sys
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from supabase import create_client
from config import get_settings
from logging_config import setup_logging, get_logger
from services.product_service import ProductService

setup_logging()
logger = get_logger(__name__)

async def main():
    parser = argparse.ArgumentParser(description="Batch fill empty product columns")
    parser.add_argument("--table", required=True, choices=["products", "designerproducts", "manufacturerproducts"],
                        help="Table to process")
    parser.add_argument("--limit", type=int, default=20, help="Number of products to process")
    parser.add_argument("--dry-run", action="store_true", help="Don't actually update database")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")

    args = parser.parse_args()

    if args.verbose:
        setup_logging("DEBUG")

    logger.info("Starting batch fill for table: %s, limit: %s", args.table, args.limit)

    # Initialize
    settings = get_settings()
    supabase = create_client(settings.database_url, settings.database_key)
    service = ProductService(supabase)

    if args.dry_run:
        logger.info("DRY RUN MODE - No changes will be made")

    try:
        results = await service.batch_fill(args.table, args.limit)

        logger.info(f"Batch complete!")
        logger.info(f"  Total: {results['total']}")
        logger.info(f"  Success: {results['success']}")
        logger.info(f"  Failed: {results['failed']}")

        if args.dry_run:
            logger.info("DRY RUN - Showing what would be updated:")
            for detail in results.get("details", [])[:5]:
                if "filled_columns" in detail:
                    logger.info(f"  Product {detail['product_id']}: {detail['filled_columns']}")

        return 0 if results["failed"] == 0 else 1

    except Exception as e:
        logger.error(f"Error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
