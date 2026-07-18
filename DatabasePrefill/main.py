"""FastAPI application entry point."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import sys
from pathlib import Path

# Add root dir to pythonpath to find config/logging modules
sys.path.insert(0, str(Path(__file__).parent))

from config import get_settings
from logging_config import setup_logging, get_logger
from backend.routes.routes import router

# Setup
settings = get_settings()
setup_logging(settings.log_level)
logger = get_logger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Database Prefill API",
    description="AI-powered product detail filling service for jewelry",
    version="1.0.0",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Adjust in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(router, prefix="/api/v1", tags=["products"])

# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info("Database Prefill API starting up...")
    logger.info(f"Database URL configured: {'Yes' if settings.database_url else 'No'}")
    # logger.info(f"Database URL: {settings.database_url}")
    # logger.info(f"Database Secret Key: {settings.database_secret_key}")
    # logger.info(f"API Key: {settings.api_key}")
    # logger.info(f"SECRET key: {settings.service_api_key}")
    # logger.info(f"Log Level: {settings.log_level}")
    # logger.info(f"API Timeout: {settings.api_timeout_request}")
    logger.info(f"Model name: {settings.llm_model}")
    # logger.info(f"SECRET key: {settings.service_api_key}")
# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Database Prefill API shutting down...")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=7860, reload=True)
