"""Service for handling CSV upload and processing."""
import csv
import io
from typing import Dict, Any, List

from .llm_service import LLMService
from constants import TARGET_COLUMNS
from logging_config import get_logger
from config import get_settings


logger = get_logger(__name__)
settings=get_settings()

class CsvService:
    """Service for processing uploaded CSV files with LLM."""

    def __init__(self):
        self.llm = LLMService(llm_model=settings.llm_model)

    def _get_image_url(self, row: Dict[str, Any]) -> str:
        """Attempt to extract image URL from a row."""
        for key in ["Image", "Images", "image", "Image URL", "image_url"]:
            if key in row and row[key]:
                # In case it's a comma-separated list or JSON array string, take the first URL
                val = row[key].strip()
                if val.startswith('[') and val.endswith(']'):
                    # basic stripping for "[url1, url2]" formats
                    val = val.strip('[]').split(',')[0].strip(' "\'')
                else:
                    val = val.split(',')[0].strip()
                if val.startswith('http'):
                    return val
        return ""

    # Target columns that are text[] arrays (post-Phase-3 schema).
    _LIST_COLS = {
        "Product Tags", "Stone Type", "Stone Used", "Stone Setting",
        "Stone Count", "Metal Color", "Stone Color", "Stone Cut",
        "Enamel Work", "Category", "Studded",
    }

    def _filter_updates(
        self,
        existing_data: Dict[str, Any],
        extracted_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Fill only the target columns that are currently empty in this row.

        The LLM output keys already match the column names (spaced aliases via
        the response schema), so we look them up directly — no underscore
        remapping needed.
        """
        updates: Dict[str, Any] = {}

        for col in TARGET_COLUMNS:
            # LLM may key by the spaced alias or the underscored field name.
            val = extracted_data.get(col)
            if val is None:
                val = extracted_data.get(col.replace(" ", "_"))
            existing_val = existing_data.get(col)

            # Only fill columns the CSV currently leaves null/empty.
            if existing_val is None or str(existing_val).strip().lower() in ["", "[]", "null", "none"]:
                if val is None or val == "" or val == []:
                    # AI returned nothing usable — leave a positive placeholder
                    # so the output has no bare nulls.
                    val = ["None"] if col in self._LIST_COLS else "None"
                elif col in self._LIST_COLS and not isinstance(val, list):
                    val = [val]
                updates[col] = val
        return updates

    async def process_csv(self, file_contents: str) -> str:
        """
        Parse CSV, process rows with missing target columns using LLM,
        and return the updated CSV string.
        """
        reader = csv.DictReader(io.StringIO(file_contents))
        if not reader.fieldnames:
            raise ValueError("CSV file has no header row.")
        
        fieldnames = list(reader.fieldnames)
        
        # Ensure all target columns exist in the output headers
        for col in TARGET_COLUMNS:
            if col not in fieldnames:
                fieldnames.append(col)

        rows = list(reader)
        updated_rows = []

        for index, row in enumerate(rows):
            # Check if any target column is missing
            needs_update = False
            for col in TARGET_COLUMNS:
                val = row.get(col)
                if val is None or str(val).strip().lower() in ["", "[]", "null", "none"]:
                    needs_update = True
                    break

            if needs_update:
                image_url = self._get_image_url(row)
                if image_url:
                    logger.info(f"Processing row {index + 1} with image: {image_url}")
                    try:
                        extracted_data = await self.llm.analyze_product_image(
                            image_url=image_url,
                            existing_data=row
                        )
                        updates = self._filter_updates(row, extracted_data)
                        if updates:
                            for k, v in updates.items():
                                if isinstance(v, list):
                                    row[k] = ", ".join(map(str, v))
                                else:
                                    row[k] = str(v)
                            logger.info(f"Row {index + 1} updated columns: {list(updates.keys())}")
                    except Exception as e:
                        logger.error(f"Failed to process row {index + 1}: {e}")
                else:
                    logger.warning(f"Row {index + 1} needs updates but no image URL found.")

            updated_rows.append(row)

        # Write to a new CSV buffer
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(updated_rows)
        
        return output.getvalue()