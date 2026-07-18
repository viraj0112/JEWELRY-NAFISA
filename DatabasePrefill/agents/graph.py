"""LangGraph workflow definitions."""
from langgraph.graph import StateGraph, END
from agents.state import ProductAnalysisState
from agents.product_agent import ProductAgent

def create_product_analysis_graph() -> StateGraph:
    """
    Create the main product analysis workflow graph.

    This defines the complete flow:
    1. Extract attributes from image
    2. Validate and score confidence
    3. Prepare database updates
    4. Return result
    """
    agent = ProductAgent()
    return agent.graph

# Singleton graph instance
_product_analysis_graph = None

def get_product_analysis_graph() -> StateGraph:
    """Get or create the product analysis graph."""
    global _product_analysis_graph
    if _product_analysis_graph is None:
        _product_analysis_graph = create_product_analysis_graph()
    return _product_analysis_graph
