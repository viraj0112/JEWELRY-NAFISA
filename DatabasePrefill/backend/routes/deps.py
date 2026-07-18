from dataclasses import dataclass
from typing import Annotated, Optional

from fastapi import HTTPException, Depends, Header
from supabase import create_client, Client

from config import get_settings
from logging_config import get_logger

logger = get_logger(__name__)
settings = get_settings()


def get_supabase() -> Client:
    """Service-role Supabase client (bypasses RLS) for backend lookups."""
    return create_client(settings.database_url, settings.database_secret_key)


SupabaseClient = Annotated[Client, Depends(get_supabase)]


@dataclass
class AuthContext:
    """Resolved caller identity + the LLM credentials this request should use."""
    user_id: Optional[str]
    role: str                 # 'admin' | 'designer' | 'manufacturer' | 'member'
    is_admin: bool
    llm_api_key: Optional[str]
    llm_model: Optional[str]

    # Product tables a designer/manufacturer owns rows in (for own-row scoping).
    @property
    def own_table(self) -> Optional[str]:
        if self.role == "designer":
            return "designerproducts"
        if self.role == "manufacturer":
            return "manufacturerproducts"
        return None


def _resolve_llm_settings(supabase: Client) -> tuple[Optional[str], str]:
    """Return (global_llm_api_key, default_model) from the admin settings row."""
    try:
        resp = (
            supabase.table("llm_settings")
            .select("global_llm_api_key, default_model")
            .eq("id", 1)
            .maybe_single()
            .execute()
        )
        data = resp.data or {}
        return data.get("global_llm_api_key"), (data.get("default_model") or settings.llm_model)
    except Exception as e:
        logger.warning(f"Could not read llm_settings: {e}")
        return None, settings.llm_model


async def get_auth_context(
    supabase: SupabaseClient,
    x_api_key: str = Header(..., description="Your per-user API key"),
) -> AuthContext:
    """Validate the x-api-key against api_credentials, resolve the user, and
    compute the effective LLM key/model (user's own overrides admin global)."""
    if not x_api_key:
        raise HTTPException(status_code=401, detail="API key required")

    # Admin's global key still works as a master key for admin-run fills.
    is_master = bool(settings.service_api_key) and x_api_key == settings.service_api_key

    cred = None
    try:
        resp = (
            supabase.table("api_credentials")
            .select("user_id, llm_api_key, llm_model, is_active")
            .eq("x_api_key", x_api_key)
            .maybe_single()
            .execute()
        )
        cred = resp.data
    except Exception as e:
        logger.warning(f"api_credentials lookup failed: {e}")

    if not cred and not is_master:
        raise HTTPException(status_code=401, detail="Invalid API key")
    if cred and cred.get("is_active") is False:
        raise HTTPException(status_code=403, detail="API key is disabled")

    user_id = cred.get("user_id") if cred else None
    role = "member"
    if user_id:
        try:
            urow = (
                supabase.table("users").select("role").eq("id", user_id)
                .maybe_single().execute()
            )
            role = (urow.data or {}).get("role") or "member"
        except Exception as e:
            logger.warning(f"user role lookup failed: {e}")
    is_admin = is_master or role == "admin"

    global_key, default_model = _resolve_llm_settings(supabase)

    # Precedence: the user's own LLM key/model wins; else admin global; else env.
    user_key = (cred or {}).get("llm_api_key")
    user_model = (cred or {}).get("llm_model")
    effective_key = user_key or global_key or settings.api_key
    effective_model = user_model or default_model

    return AuthContext(
        user_id=user_id,
        role=role,
        is_admin=is_admin,
        llm_api_key=effective_key,
        llm_model=effective_model,
    )


Auth = Annotated[AuthContext, Depends(get_auth_context)]


# --- Backwards-compatible simple verifier (still used by /process-csv) --------
def verify_api_key(x_api_key: str = Header(..., description="Your API Key")) -> str:
    if not x_api_key:
        raise HTTPException(status_code=401, detail="API key required")
    if x_api_key != settings.service_api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return x_api_key


VerifiedAPIKey = Annotated[str, Depends(verify_api_key)]
