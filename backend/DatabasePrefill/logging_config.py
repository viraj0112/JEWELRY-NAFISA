
import logging
import warnings
import sys
from typing import Any

def setup_logging(level:str = "INFO")->str:
    logging.basicConfig(
        level = getattr(logging, level.upper()),
        format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers = [
            logging.StreamHandler(sys.stdout)
        ]
    )
    warnings.simplefilter("ignore", category=FutureWarning)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
