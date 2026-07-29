"""Symmetric crypto for credentials read out of Supabase.

Mirrors supabase/functions/_shared/crypto.ts exactly — same key, same wire
format — so a secret written by the `ai-credentials` edge function can be read
here, and vice versa. If you change one, change both.

Wire format:  v1.<base64 iv>.<base64 ciphertext||tag>   (AES-256-GCM, 12-byte IV)

The key lives in the environment (AI_FILL_ENC_KEY, base64 of 32 raw bytes),
never in Postgres — that is the whole point: a database dump yields ciphertext
the database itself cannot decrypt.

Generate one with:  openssl rand -base64 32
"""

from __future__ import annotations

import base64
import hashlib
import os
from functools import lru_cache
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from config import get_settings
from logging_config import get_logger

logger = get_logger(__name__)

_VERSION = "v1"
_IV_BYTES = 12


class CryptoConfigError(RuntimeError):
    """Raised when AI_FILL_ENC_KEY is missing or malformed."""


@lru_cache(maxsize=1)
def _key() -> AESGCM:
    # config.Settings reads .env.local; the raw env var wins so a deployment
    # can inject the secret without shipping a file.
    raw = (os.getenv("AI_FILL_ENC_KEY") or get_settings().ai_fill_enc_key or "").strip()
    if not raw:
        raise CryptoConfigError(
            "AI_FILL_ENC_KEY is not set (expected base64 of 32 random bytes)"
        )
    try:
        key_bytes = base64.b64decode(raw)
    except Exception as exc:  # noqa: BLE001 - surfaced as config error
        raise CryptoConfigError(f"AI_FILL_ENC_KEY is not valid base64: {exc}") from exc
    if len(key_bytes) != 32:
        raise CryptoConfigError(
            f"AI_FILL_ENC_KEY must decode to 32 bytes for AES-256, got {len(key_bytes)}"
        )
    return AESGCM(key_bytes)


def encrypt_secret(plaintext: str) -> str:
    """Encrypt to the shared `v1.<iv>.<ct>` envelope."""
    iv = os.urandom(_IV_BYTES)
    ct = _key().encrypt(iv, plaintext.encode("utf-8"), None)
    return f"{_VERSION}.{base64.b64encode(iv).decode()}.{base64.b64encode(ct).decode()}"


def decrypt_secret(payload: str) -> str:
    """Decrypt a `v1.<iv>.<ct>` envelope. Raises on tampering (GCM auth tag)."""
    parts = (payload or "").split(".")
    if len(parts) != 3 or parts[0] != _VERSION:
        raise ValueError("Unrecognised ciphertext format")
    iv = base64.b64decode(parts[1])
    ct = base64.b64decode(parts[2])
    return _key().decrypt(iv, ct, None).decode("utf-8")


def try_decrypt(payload: Optional[str]) -> Optional[str]:
    """Best-effort decrypt used on the request path.

    Returns None instead of raising so one unreadable row (bad key rotation,
    legacy value) degrades to "no user key -> fall back to the global key"
    rather than 500-ing the whole fill request.
    """
    if not payload:
        return None
    try:
        return decrypt_secret(payload)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Could not decrypt stored secret: %s", exc)
        return None


def sha256_hex(value: str) -> str:
    """Hex SHA-256 — how an incoming x-api-key is matched against the stored
    hash without the plaintext ever being persisted."""
    return hashlib.sha256(value.encode("utf-8")).hexdigest()
