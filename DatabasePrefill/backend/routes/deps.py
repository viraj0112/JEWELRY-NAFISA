from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Annotated, Any, Optional

from fastapi import HTTPException, Depends, Header
from supabase import create_client, Client

from config import get_settings
from logging_config import get_logger
from backend.services.crypto_service import sha256_hex, try_decrypt

logger = get_logger(__name__)
settings = get_settings()


def _parse_ts(value: Any) -> Optional[datetime]:
    """Parse a Postgres timestamptz string into an aware datetime."""
    if not value:
        return None
    try:
        # Postgres emits '+00:00' or 'Z'; fromisoformat only learned 'Z' in 3.11.
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        logger.warning("Unparseable timestamp from api_credentials: %r", value)
        return None


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
    """Return (global_llm_api_key, default_model) from the admin settings row.

    The key is stored AES-GCM encrypted; `global_llm_api_key` is only present
    for rows written before the encryption migration.
    """
    try:
        resp = (
            supabase.table("llm_settings")
            .select("global_llm_api_key, global_llm_api_key_enc, default_model")
            .eq("id", 1)
            .maybe_single()
            .execute()
        )
        data = resp.data or {}
        key = try_decrypt(data.get("global_llm_api_key_enc")) or data.get("global_llm_api_key")
        return key, (data.get("default_model") or settings.llm_model)
    except Exception as e:
        logger.warning(f"Could not read llm_settings: {e}")
        return None, settings.llm_model


def _lookup_credential(supabase: Client, x_api_key: str) -> Optional[dict]:
    """Find the credential row for an incoming x-api-key.

    Primary path: match SHA-256(key) against `x_api_key_hash`. The plaintext
    is never stored, so a database compromise does not hand over working keys —
    the same reason password columns hold hashes.

    Fallback: keys issued before the hashing migration still sit in the legacy
    plaintext `x_api_key` column. That path disappears the first time each key
    is rotated.
    """
    columns = (
        "user_id, llm_api_key, llm_api_key_enc, llm_model, is_active, expires_at"
    )
    try:
        resp = (
            supabase.table("api_credentials")
            .select(columns)
            .eq("x_api_key_hash", sha256_hex(x_api_key))
            .maybe_single()
            .execute()
        )
        if resp and resp.data:
            return resp.data
    except Exception as e:
        logger.warning(f"api_credentials hash lookup failed: {e}")

    try:
        resp = (
            supabase.table("api_credentials")
            .select(columns)
            .eq("x_api_key", x_api_key)
            .maybe_single()
            .execute()
        )
        return resp.data if resp else None
    except Exception as e:
        logger.warning(f"api_credentials legacy lookup failed: {e}")
        return None


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

    cred = _lookup_credential(supabase, x_api_key)

    if not cred and not is_master:
        raise HTTPException(status_code=401, detail="Invalid API key")
    if cred and cred.get("is_active") is False:
        raise HTTPException(status_code=403, detail="API key is disabled")

    # TTL. NULL expires_at means the admin chose "never". Comparing in UTC
    # because Postgres hands back an offset-aware timestamp and naive/aware
    # comparison would raise instead of denying.
    if cred:
        expires_at = _parse_ts(cred.get("expires_at"))
        if expires_at is not None and expires_at <= datetime.now(timezone.utc):
            raise HTTPException(
                status_code=403,
                detail="API key has expired. Ask your admin to generate a new one.",
            )

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
    # `llm_api_key_enc` is the encrypted column; the bare one is legacy-only.
    user_key = try_decrypt((cred or {}).get("llm_api_key_enc")) or (cred or {}).get("llm_api_key")
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
