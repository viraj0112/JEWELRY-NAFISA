
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
    llm_rate_limit_retries: int = 5   # extra retries reserved for 429s
    llm_max_retry_delay: float = 60.0 # cap on any single wait, seconds
    # Fallback requests/minute per API key when the admin setting is absent
    # (0 = no limit). The admin value in llm_settings takes precedence.
    llm_requests_per_minute: int = 10
    # --- Cost / accuracy knobs ---
    llm_image_max_side: int = 1024    # px; larger photos are downscaled (0 = off)
    llm_thinking_level: str = "low"   # Gemini 3+: "low" | "high" | "" (model default)
    llm_thinking_budget: int = 512    # Gemini 2.5: thinking tokens (-1 = model default)
    llm_media_resolution: str = ""    # e.g. "MEDIA_RESOLUTION_MEDIUM"; "" = model default
    # --- Processed-row tracker (skip already-filled rows) ---
    processed_tracker_file: str = "processed_rows.json"

@lru_cache(maxsize=128)
def get_settings()->Settings:
    return Settings()