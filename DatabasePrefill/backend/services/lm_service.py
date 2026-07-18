
import httpx
import asyncio
import json
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
from google import genai
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


class LLMService:
    def __init__(self, llm_model: str = None, api_key: str = None):
        # api_key precedence: explicit (per-user/admin-global) -> env default.
        resolved_key = api_key or settings.api_key
        if not resolved_key:
            raise ValueError(
                "No LLM API key available: set one for the user/admin, or api_key in .env"
            )
        self.client = genai.Client(api_key=resolved_key)
        # Fall back to the configured model when a caller constructs the service
        # without passing one — otherwise model=None makes the SDK POST to the
        # literal `/v1beta/{model}:generateContent` template URL, which 404s.
        self.llm_model = llm_model or settings.llm_model
        if not self.llm_model:
            raise ValueError(
                "No LLM model configured: pass llm_model or set llm_model in settings/.env"
            )
    
    # Substrings that mark a PERMANENT failure — retrying these is pointless.
    _PERMANENT_ERROR_MARKERS = (
        "invalid", "permission", "unauthorized", "api key", "api_key",
        "not found", "quota exceeded", "safety",
    )

    async def _generate_with_retry(self, prompt: str, image_part) -> Any:
        """Call Gemini off the event loop (the SDK call is blocking) with
        exponential-backoff retries on transient failures (429/500/503/timeout).
        Blocking the loop is what made the server stop responding under load."""
        last_err: Optional[Exception] = None
        for attempt in range(1, settings.llm_max_retries + 1):
            try:
                return await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=self.llm_model,
                    contents=[prompt, image_part],
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=JewelryExtractionSchema,  # Forces compliance
                        temperature=0.4,                          # factual, low creativity
                    ),
                )
            except Exception as e:
                last_err = e
                if any(m in str(e).lower() for m in self._PERMANENT_ERROR_MARKERS):
                    raise  # don't waste retries on a permanent error
                if attempt < settings.llm_max_retries:
                    delay = settings.llm_retry_base_delay * (2 ** (attempt - 1))
                    logger.warning(
                        f"Gemini call failed (attempt {attempt}/{settings.llm_max_retries}): "
                        f"{e}; retrying in {delay:.1f}s"
                    )
                    await asyncio.sleep(delay)
        raise last_err  # exhausted retries

    async def analyze_product_image(
        self,
        image_url: str,
        existing_data: Optional[Dict[str, Any]] = None,
        custom_prompt: Optional[str] = None
    ) -> Dict[str, Any]:
        """Analyze a product image and extract attributes with guaranteed schema output."""
        try:
            # 1. Download image asynchronously
            async with httpx.AsyncClient() as http_client:
                image_response = await http_client.get(image_url, timeout=settings.api_timeout_request)
                image_response.raise_for_status()
                image_bytes = image_response.content
                content_type = image_response.headers.get("Content-Type", "image/jpeg")
            image_part = types.Part.from_bytes(data=image_bytes, mime_type=content_type)
            # 2. Build prompt
            prompt = custom_prompt or DATA_SCRAPER_PROMPT
            if existing_data:
                prompt += f"\n\nExisting product data context:\n{existing_data}"
            # 3. Request Gemini (non-blocking, with retries)
            response = await self._generate_with_retry(prompt, image_part)
            # 4. Parse returned JSON (SDK validates against response_schema)
            import json
            extracted_data = json.loads(response.text)

            logger.info(f"Successfully analyzed image: {image_url}")
            return extracted_data
        except Exception as e:
            logger.error(f"Error analyzing image {image_url}: {e}")
            raise

    async def batch_analyze(
        self,
        image_urls: List[str],
        max_concurrency: Optional[int] = None,
    )->List[Dict[str, Any]]:
        """Process multiple images concurrently using a Semaphore."""
        limit = max_concurrency or settings.llm_max_concurrency
        semaphore = asyncio.Semaphore(limit)
        async def worker(url: str):
            async with semaphore:
                try:
                    return await self.analyze_product_image(url)
                except Exception as e:
                    logger.warning(f"Failed to process image {url}: {e}")
                    return {"image_url": url, "error": str(e)}
        tasks = [worker(url) for url in image_urls]
        return await asyncio.gather(*tasks, return_exceptions=False)

        