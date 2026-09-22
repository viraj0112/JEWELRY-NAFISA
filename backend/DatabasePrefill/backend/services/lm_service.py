
import httpx
import asyncio
import hashlib
import io
import json
import re
import time
from functools import lru_cache
from urllib.parse import unquote, urlparse
from pydantic import BaseModel, ConfigDict, Field, create_model
from typing import Dict, Any, FrozenSet, Iterable, Optional, List, Tuple
from google import genai
from google.genai import errors as genai_errors
from google.genai import types
from config import get_settings
from logging_config import get_logger
from prompts.prompts import DATA_SCRAPER_PROMPT

logger = get_logger(__name__)
settings = get_settings()

# Definition of schema for LLM model.
class JewelryExtractionSchema(BaseModel):
    Description: str = Field(description="Detailed SEO-optimized product description")
    Product_Tags: List[str] = Field(alias="Product Tags", description="List of relevant searchable tags")
    Metal_Finish: str = Field(alias="Metal Finish", description="Type of metal finish (e.g., High Polish, Matte)")
    Stone_Type: List[str] = Field(alias="Stone Type", description="Gemstones used (e.g., Diamond, Ruby)")
    Stone_Used: List[str] = Field(alias="Stone Used", description="Stone material from the fixed allowed list, or ['None']")
    Stone_Setting: List[str] = Field(alias="Stone Setting", description="Prong, Bezel, Pave etc.")
    Stone_Count: List[str] = Field(alias="Stone Count", description="Total stone count as list of strings")
    Metal_Color: List[str] = Field(alias="Metal Color", description="Yellow Gold, White Gold, or Rose Gold only")
    Stone_Color: List[str] = Field(alias="Stone Color", description="White, Blue, Pink etc.")
    Stone_Cut: List[str] = Field(alias="Stone Cut", description="Round, Princess, Oval etc.")
    Stone_Quality: List[str] = Field(alias="Stone Quality", description="VVS, VS, VS1, VS2, SI, SI1, SI2, IF, FL, or ['Not Applicable']")
    Enamel_Work: List[str] = Field(alias="Enamel Work", description="Visible enamel colors, or ['None']")
    Category: List[str] = Field(description="['<Stone Category> <Product Type>'] per stone, or ['Plain Gold <Product Type>']")
    Plain: str = Field(description="'True' if no stones are present, 'False' otherwise")
    Studded: List[str] = Field(description="['Diamond'], ['Gemstone'], or ['None']")
    Plating: str = Field(description="Gold Plated, Rhodium Plated, or 'Not Plated (Solid Metal)'")

    model_config = {
        "populate_by_name": True # Allows parsing variables even with aliases (like "Product Tags")
    }


@lru_cache(maxsize=256)
def _schema_for(columns: FrozenSet[str]) -> type[BaseModel]:
    """The extraction schema narrowed to `columns` (real DB column names).

    Asking only for the columns a row is actually missing cuts output tokens
    (the answer is billed per token) and focuses the model on those fields
    instead of re-describing attributes the seller already recorded.
    """
    fields = {
        name: (info.annotation, info)
        for name, info in JewelryExtractionSchema.model_fields.items()
        if (info.alias or name) in columns
    }
    if not fields:
        return JewelryExtractionSchema
    return create_model(
        "JewelryPartialExtraction",
        __config__=ConfigDict(populate_by_name=True),
        **fields,
    )


def _empty_usage() -> Dict[str, int]:
    # cached_tokens is the part of input_tokens served from Gemini's implicit
    # prompt cache (billed at a discount) - the static instructions prefix.
    return {"input_tokens": 0, "cached_tokens": 0, "output_tokens": 0, "thinking_tokens": 0}


class _RateLimiter:
    """Spaces out request starts per API key so a batch stays under the
    provider's requests-per-minute limit instead of bursting into 429s.

    Keyed by a hash of the API key (never the key itself); process-wide, so
    concurrent fills sharing one key share its budget.
    """

    def __init__(self):
        self._next_slot: Dict[str, float] = {}
        self._locks: Dict[str, asyncio.Lock] = {}

    async def wait_turn(self, api_key: str, requests_per_minute: int) -> None:
        if requests_per_minute <= 0:
            return
        bucket = hashlib.sha256(api_key.encode()).hexdigest()[:16]
        lock = self._locks.setdefault(bucket, asyncio.Lock())
        interval = 60.0 / requests_per_minute
        async with lock:
            now = time.monotonic()
            slot = max(now, self._next_slot.get(bucket, 0.0))
            self._next_slot[bucket] = slot + interval
        delay = slot - now
        if delay > 0:
            await asyncio.sleep(delay)


_rate_limiter = _RateLimiter()


class LLMService:
    # Models that rejected a thinking setting; they get the model default.
    _no_thinking_models: set = set()

    def __init__(
        self,
        llm_model: str = None,
        api_key: str = None,
        requests_per_minute: Optional[int] = None,
    ):
        # api_key precedence: explicit (per-user/admin-global) -> env default.
        resolved_key = api_key or settings.api_key
        if not resolved_key:
            raise ValueError(
                "No LLM API key available: set one for the user/admin, or api_key in .env"
            )
        self._api_key = resolved_key
        self.client = genai.Client(api_key=resolved_key)
        # Fall back to the configured model when a caller constructs the service
        # without passing one — otherwise model=None makes the SDK POST to the
        # literal `/v1beta/{model}:generateContent` template URL, which 404s.
        self.llm_model = llm_model or settings.llm_model
        if not self.llm_model:
            raise ValueError(
                "No LLM model configured: pass llm_model or set llm_model in settings/.env"
            )
        self.requests_per_minute = (
            settings.llm_requests_per_minute
            if requests_per_minute is None else requests_per_minute
        )

    # Substrings that mark a PERMANENT failure — retrying these is pointless.
    # (Rate limits are handled separately: a per-minute quota is transient.)
    _PERMANENT_ERROR_MARKERS = (
        "invalid", "permission", "unauthorized", "api key", "api_key",
        "not found", "no longer available", "safety",
    )

    @staticmethod
    def _is_rate_limit(err: Exception) -> bool:
        code = getattr(err, "code", None)
        text = str(err)
        return code == 429 or text.startswith("429") or "RESOURCE_EXHAUSTED" in text

    @staticmethod
    def _is_daily_quota(err: Exception) -> bool:
        # Daily quotas reset at midnight Pacific; waiting minutes won't help.
        return "PerDay" in str(err)

    @staticmethod
    def _retry_delay_hint(err: Exception) -> Optional[float]:
        """Seconds Google asks us to wait (RetryInfo.retryDelay), if given."""
        match = re.search(r"retryDelay['\"]?\s*:\s*['\"]?(\d+(?:\.\d+)?)s", str(err))
        return float(match.group(1)) if match else None

    def _thinking_config(self) -> Optional[types.ThinkingConfig]:
        """Cap reasoning effort. Thinking tokens are billed as output, and
        reading attributes off a product photo doesn't need deep reasoning.
        Gemini 3+ takes a level; 2.5 takes a token budget; others: default."""
        if self.llm_model in self._no_thinking_models:
            return None
        match = re.match(r"gemini-(\d+(?:\.\d+)?)", self.llm_model)
        version = float(match.group(1)) if match else 0.0
        if version >= 3 and settings.llm_thinking_level:
            return types.ThinkingConfig(thinking_level=settings.llm_thinking_level)
        if 2.5 <= version < 3 and settings.llm_thinking_budget >= 0:
            return types.ThinkingConfig(thinking_budget=settings.llm_thinking_budget)
        return None

    def _generation_config(self, schema: type[BaseModel], with_thinking: bool):
        config = dict(
            response_mime_type="application/json",
            response_schema=schema,           # Forces compliance
            temperature=0.4,                  # factual, low creativity
        )
        thinking = self._thinking_config() if with_thinking else None
        if thinking is not None:
            config["thinking_config"] = thinking
        if settings.llm_media_resolution:
            config["media_resolution"] = settings.llm_media_resolution
        return types.GenerateContentConfig(**config)

    async def _generate_with_retry(
        self, prompt: str, image_part, schema: type[BaseModel] = JewelryExtractionSchema
    ) -> Any:
        """Call Gemini off the event loop (the SDK call is blocking) with
        backoff retries on transient failures.

        Rate limits (429) get their own, longer retry budget and honour the
        delay Google suggests; a daily quota is reported immediately since it
        won't clear within a run. Blocking the loop is what made the server
        stop responding under load."""
        last_err: Optional[Exception] = None
        attempt = rate_limit_attempt = 0
        with_thinking = True
        while True:
            attempt += 1
            await _rate_limiter.wait_turn(self._api_key, self.requests_per_minute)
            try:
                return await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=self.llm_model,
                    contents=[prompt, image_part],
                    config=self._generation_config(schema, with_thinking),
                )
            except Exception as e:
                last_err = e
                text = str(e).lower()

                # A model that doesn't accept the thinking setting: retry once
                # without it and remember, rather than failing every product.
                if with_thinking and "thinking" in text and getattr(e, "code", None) == 400:
                    logger.warning(f"{self.llm_model} rejected thinking config; using model default")
                    self._no_thinking_models.add(self.llm_model)
                    with_thinking = False
                    attempt -= 1
                    continue

                if self._is_rate_limit(e):
                    if self._is_daily_quota(e):
                        raise
                    rate_limit_attempt += 1
                    if rate_limit_attempt > settings.llm_rate_limit_retries:
                        raise
                    hint = self._retry_delay_hint(e)
                    delay = min(
                        hint if hint is not None
                        else settings.llm_retry_base_delay * (2 ** rate_limit_attempt),
                        settings.llm_max_retry_delay,
                    )
                    logger.warning(
                        f"Rate limited by Gemini (attempt {rate_limit_attempt}/"
                        f"{settings.llm_rate_limit_retries}); waiting {delay:.1f}s"
                    )
                    await asyncio.sleep(delay)
                    continue

                if any(m in text for m in self._PERMANENT_ERROR_MARKERS):
                    raise  # don't waste retries on a permanent error
                if attempt >= settings.llm_max_retries:
                    raise last_err  # exhausted retries
                delay = settings.llm_retry_base_delay * (2 ** (attempt - 1))
                logger.warning(
                    f"Gemini call failed (attempt {attempt}/{settings.llm_max_retries}): "
                    f"{e}; retrying in {delay:.1f}s"
                )
                await asyncio.sleep(delay)

    @staticmethod
    def _prepare_image(data: bytes, content_type: str) -> Tuple[bytes, str]:
        """Downscale oversized photos before upload.

        Image input is billed by resolution; a 3000px studio shot costs several
        times the tokens of a 1024px one while adding no detail the model can
        use for these attributes. Smaller images are sent untouched.
        """
        max_side = settings.llm_image_max_side
        if max_side <= 0:
            return data, content_type
        try:
            from PIL import Image

            image = Image.open(io.BytesIO(data))
            if max(image.size) <= max_side:
                return data, content_type
            image.thumbnail((max_side, max_side), Image.LANCZOS)
            if image.mode not in ("RGB", "L"):
                # Flatten transparency onto white (JPEG has no alpha).
                rgba = image.convert("RGBA")
                background = Image.new("RGB", rgba.size, (255, 255, 255))
                background.paste(rgba, mask=rgba.split()[-1])
                image = background
            out = io.BytesIO()
            image.save(out, format="JPEG", quality=90, optimize=True)
            return out.getvalue(), "image/jpeg"
        except Exception as e:
            logger.warning(f"Could not downscale image ({e}); sending original")
            return data, content_type

    @staticmethod
    def _usage_of(response: Any) -> Dict[str, int]:
        usage = _empty_usage()
        meta = getattr(response, "usage_metadata", None)
        if meta is not None:
            usage["input_tokens"] = meta.prompt_token_count or 0
            usage["cached_tokens"] = meta.cached_content_token_count or 0
            usage["output_tokens"] = meta.candidates_token_count or 0
            usage["thinking_tokens"] = meta.thoughts_token_count or 0
        return usage

    async def analyze_product_image(
        self,
        image_url: str,
        existing_data: Optional[Dict[str, Any]] = None,
        custom_prompt: Optional[str] = None,
        columns: Optional[Iterable[str]] = None,
    ) -> Dict[str, Any]:
        """Analyze a product image and extract attributes with guaranteed schema output."""
        data, _usage = await self.analyze_with_usage(
            image_url, existing_data, custom_prompt, columns
        )
        return data

    async def analyze_with_usage(
        self,
        image_url: str,
        existing_data: Optional[Dict[str, Any]] = None,
        custom_prompt: Optional[str] = None,
        columns: Optional[Iterable[str]] = None,
    ) -> Tuple[Dict[str, Any], Dict[str, int]]:
        """Like `analyze_product_image`, also returning token usage.

        `columns` limits the answer to those DB columns (the ones still empty);
        None asks for the full schema.
        """
        try:
            # 1. Download image asynchronously
            async with httpx.AsyncClient() as http_client:
                image_response = await http_client.get(image_url, timeout=settings.api_timeout_request)
                image_response.raise_for_status()
                image_bytes = image_response.content
                content_type = image_response.headers.get("Content-Type", "image/jpeg")
            image_bytes, content_type = self._prepare_image(image_bytes, content_type)
            image_part = types.Part.from_bytes(data=image_bytes, mime_type=content_type)
            # 2. Build prompt
            prompt = custom_prompt or DATA_SCRAPER_PROMPT
            image_name = unquote(urlparse(image_url).path.rsplit("/", 1)[-1])
            if image_name:
                prompt += (
                    "\n\nImage filename metadata (use as supporting product context, "
                    "but verify it against the image):\n"
                    f"{image_name}"
                )
            if existing_data:
                # The schema forces a value for every field, so the model will
                # answer for columns that are already populated too. Those
                # answers are discarded on the write side — this instruction
                # makes the ones we DO keep consistent with them (e.g. a
                # Description written against the recorded metal colour rather
                # than the model's own guess from the photo).
                prompt += (
                    "\n\nAlready-recorded data for this product (treat as "
                    "authoritative — it was set by the seller and outranks your "
                    "reading of the image; stay consistent with it and do not "
                    "contradict it):\n"
                    f"{json.dumps(existing_data, ensure_ascii=False, default=str)}"
                )
            schema = _schema_for(frozenset(columns)) if columns else JewelryExtractionSchema
            if schema is not JewelryExtractionSchema:
                prompt += (
                    "\n\nOnly these fields are missing; answer just these, "
                    "applying the rules above for each: "
                    f"{', '.join(sorted(columns))}"
                )
            # 3. Request Gemini (non-blocking, with retries)
            response = await self._generate_with_retry(prompt, image_part, schema)
            # 4. Parse returned JSON (SDK validates against response_schema)
            extracted_data = json.loads(response.text)

            logger.info(f"Successfully analyzed image: {image_url}")
            return extracted_data, self._usage_of(response)
        except Exception as e:
            logger.error(f"Error analyzing image {image_url}: {e}")
            raise

    async def batch_analyze(
        self,
        image_urls: List[str],
        existing_data: Optional[List[Optional[Dict[str, Any]]]] = None,
        max_concurrency: Optional[int] = None,
        columns: Optional[List[Optional[Iterable[str]]]] = None,
    )->List[Dict[str, Any]]:
        """Process multiple images concurrently using a Semaphore.

        `existing_data[i]` is the already-known attributes of the product behind
        `image_urls[i]` — the same context `analyze_product_image` accepts for a
        single fill. Passing it keeps the batch path consistent with the single
        path: the model sees what the row already says and extends it, instead
        of describing the image from scratch and contradicting the human.
        `columns[i]` narrows the answer to that product's empty columns.

        Each result is `{"data": ..., "usage": ...}` on success or
        `{"error": ..., "usage": ...}` on failure. Results stay positional
        (`gather` preserves order), so callers can keep zipping results back to
        their products.
        """
        limit = max_concurrency or settings.llm_max_concurrency
        semaphore = asyncio.Semaphore(limit)
        async def worker(url: str, context: Optional[Dict[str, Any]], cols):
            async with semaphore:
                try:
                    data, usage = await self.analyze_with_usage(
                        url, existing_data=context, columns=cols
                    )
                    return {"data": data, "usage": usage}
                except Exception as e:
                    logger.warning(f"Failed to process image {url}: {e}")
                    return {"image_url": url, "error": str(e), "usage": _empty_usage()}
        contexts = existing_data or [None] * len(image_urls)
        column_sets = columns or [None] * len(image_urls)
        tasks = [
            worker(url, ctx, cols)
            for url, ctx, cols in zip(image_urls, contexts, column_sets)
        ]
        return await asyncio.gather(*tasks, return_exceptions=False)
