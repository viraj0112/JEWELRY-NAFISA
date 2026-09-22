"""Persistent record of rows that have already been AI-filled, so the pipeline
never re-processes (or re-bills for) the same row twice.

Stored as a JSON file keyed by table name:

    {
      "products":            [12, 15, 18, ...],
      "designerproducts":    [3, 7, ...],
      "manufacturerproducts": [...]
    }

Row identity is the integer primary key `id`. This is intentionally a simple
file (not a DB table) so it needs no schema/migration and survives restarts.
"""
import json
import threading
from pathlib import Path
from typing import Dict, Iterable, List, Set

from config import get_settings
from logging_config import get_logger

logger = get_logger(__name__)
settings = get_settings()

# Resolve the tracker file relative to the DatabasePrefill root
# (this file is <root>/backend/services/processed_tracker.py).
_ROOT = Path(__file__).resolve().parents[2]
_TRACKER_PATH = _ROOT / settings.processed_tracker_file


class ProcessedTracker:
    """Thread-safe, file-backed set of processed row ids per table."""

    def __init__(self, path: Path = _TRACKER_PATH):
        self._path = Path(path)
        self._lock = threading.Lock()
        self._data: Dict[str, Set[int]] = self._load()

    def _load(self) -> Dict[str, Set[int]]:
        if not self._path.exists():
            return {}
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
            return {table: set(ids) for table, ids in raw.items()}
        except Exception as e:
            logger.warning(f"Could not read processed tracker {self._path}: {e}; starting fresh")
            return {}

    def _flush(self) -> None:
        try:
            serializable = {table: sorted(ids) for table, ids in self._data.items()}
            tmp = self._path.with_suffix(self._path.suffix + ".tmp")
            tmp.write_text(json.dumps(serializable, indent=2), encoding="utf-8")
            tmp.replace(self._path)  # atomic on same filesystem
        except Exception as e:
            logger.error(f"Failed to write processed tracker {self._path}: {e}")

    def is_processed(self, table_name: str, row_id: int) -> bool:
        with self._lock:
            return row_id in self._data.get(table_name, set())

    def processed_ids(self, table_name: str) -> Set[int]:
        """Snapshot copy of the processed ids for a table."""
        with self._lock:
            return set(self._data.get(table_name, set()))

    def mark(self, table_name: str, row_ids: Iterable[int]) -> None:
        ids = {rid for rid in row_ids if rid is not None}
        if not ids:
            return
        with self._lock:
            self._data.setdefault(table_name, set()).update(ids)
            self._flush()

    def count(self, table_name: str) -> int:
        with self._lock:
            return len(self._data.get(table_name, set()))
