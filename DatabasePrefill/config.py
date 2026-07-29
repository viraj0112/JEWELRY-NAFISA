
from functools import lru_cache
import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    """Settings configuration"""
    model_config = SettingsConfigDict(env_file=".env.local", extra="ignore")
    api_key:str = ""
    service_api_key:str = "my-secret-key"
    database_url:str = ""
    database_secret_key:str = ""
    # Base64 of 32 random bytes (`openssl rand -base64 32`). Must be the SAME
    # value as the AI_FILL_ENC_KEY secret on the Supabase Edge Functions, or
    # keys written by one side cannot be read by the other.
    ai_fill_enc_key:str = ""
    log_level:str = "INFO"
    llm_model:str = ""
    max_batchsize:int = 20
    api_timeout_request: int = 90
    cors_origins: list[str] = ["*"]
    # --- LLM resilience knobs ---
    llm_max_concurrency: int = 4      # simultaneous Gemini calls (was 10 -> rate-limited)
    llm_max_retries: int = 3          # retries per image on transient errors
    llm_retry_base_delay: float = 2.0 # seconds; exponential backoff base
    # --- Processed-row tracker (skip already-filled rows) ---
    processed_tracker_file: str = "processed_rows.json"

@lru_cache(maxsize=128)
def get_settings()->Settings:
    return Settings()