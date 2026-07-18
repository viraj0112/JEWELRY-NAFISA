"""Main product analysis agent using LangGraph."""
from typing import Dict, Any
from langgraph.graph import StateGraph, END
from agents.state import ProductAnalysisState
from backend.services.llm_service import LLMService
from logging_config import get_logger

logger = get_logger(__name__)

class ProductAgent:
    """LangGraph agent for analyzing product images."""

    def __init__(self):
        self.llm_service = LLMService()
        self.graph = self._build_graph()

    def _build_graph(self) -> StateGraph:
        """Build the LangGraph workflow."""
        workflow = StateGraph(ProductAnalysisState)

        # Add nodes
        workflow.add_node("extract", self._extract_attributes)
        workflow.add_node("validate", self._validate_data)
        workflow.add_node("prepare_updates", self._prepare_updates)

        # Set entry point
        workflow.set_entry_point("extract")

        # Add edges
        workflow.add_edge("extract", "validate")
        workflow.add_edge("validate", "prepare_updates")
        workflow.add_edge("prepare_updates", END)

        return workflow.compile()

    async def _extract_attributes(
        self,
        state: ProductAnalysisState,
    ) -> ProductAnalysisState:
        """Extract product attributes from image using Gemini."""
        try:
            # 1. analyze image url
            result = await self.llm_service.analyze_product_image(
                image_url=state["image_url"],
                existing_data=state.get("existing_data"),
            )

            state["extracted_data"] = result
            state["errors"] = None

        except Exception as e:
            logger.error(f"Error extracting attributes: {e}")
            state["errors"] = [str(e)]
            state["extracted_data"] = {}

        return state

    async def _validate_data(
        self,
        state: ProductAnalysisState,
    ) -> ProductAnalysisState:
        """Validate extracted data and calculate confidence."""
        extracted = state.get("extracted_data", {})

        # Calculate confidence (placeholder - implement based on your needs)
        confidence_scores = {}
        for key, value in extracted.items():
            # Simple confidence based on data presence
            confidence_scores[key] = 1.0 if value else 0.0

        # Mark for review if low confidence
        needs_review = any(score < 0.85 for score in confidence_scores.values())

        state["confidence_scores"] = confidence_scores
        state["needs_review"] = needs_review

        return state

    async def _prepare_updates(
        self,
        state: ProductAnalysisState,
    ) -> ProductAnalysisState:
        """Prepare updates for database."""
        existing = state.get("existing_data", {})
        extracted = state.get("extracted_data", {})

        updates = {}
        for key, value in extracted.items():
            if value and (not existing.get(key) or existing.get(key) in [None, "", []]):
                updates[key] = value

        state["updates"] = updates
        state["result"] = {
            "product_id": state["product_id"],
            "updates": updates,
            "needs_review": state["needs_review"],
        }

        return state

    async def run(self, product_id: int, table_name: str, image_url: str, existing_data: Dict[str, Any] = None) -> Dict[str, Any]:
        """Run the agent workflow."""
        initial_state = ProductAnalysisState(
            product_id=product_id,
            table_name=table_name,
            image_url=image_url,
            existing_data=existing_data,
            extracted_data=None,
            confidence_scores=None,
            updates=None,
            needs_review=False,
            errors=None,
            result=None,
        )

        final_state = await self.graph.ainvoke(initial_state)
        return final_state.get("result", {})
