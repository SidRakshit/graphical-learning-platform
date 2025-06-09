# backend/main.py
from fastapi import FastAPI, HTTPException, Depends, status, Header
from contextlib import asynccontextmanager
from typing import List, Optional

# Import from your local modules
from db import get_db_connection, close_db_connection, Neo4jConnection
import models  # Your Pydantic models from models.py
from graph_service import GraphDBService  # Import the new service
from sagemaker_service import SageMakerService

import uuid  # Not directly used here anymore for node ID generation if service handles it
from datetime import (
    datetime,
)  # Not directly used here for timestamps if service handles it


# --- Lifespan Manager (No changes needed from last correct version) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Application startup: Attempting to initialize database connection...")
    try:
        conn_instance = get_db_connection()
        if conn_instance is None or not conn_instance._driver:  # Check internal _driver
            print(
                "FATAL: Database driver (conn_instance._driver) not initialized during startup."
            )
            # Consider raising an error to halt app startup if DB is critical
            # raise RuntimeError("Failed to initialize database driver during startup.")
        else:
            print(
                "Database connection (_driver attribute) appears to be initialized via lifespan."
            )
    except Exception as e:
        print(f"Application startup: Failed to initialize database due to: {e}")
    yield
    print("Application shutdown: Closing database connection...")
    close_db_connection()
    print("Database connection closed.")


app = FastAPI(lifespan=lifespan)


# --- Database Dependency (No changes needed from last correct version) ---
async def get_db_conn() -> (
    Neo4jConnection
):  # Renamed to avoid conflict if get_db is used for service
    db_conn_instance = get_db_connection()
    if (
        db_conn_instance is None or not db_conn_instance._driver
    ):  # Check internal _driver
        print(
            "Error in get_db_conn: Neo4jConnection instance is None or its _driver is not initialized."
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection not available or not initialized.",
        )
    return db_conn_instance


# --- Placeholder Auth Dependency (No changes needed) ---
async def get_current_user_id_from_header(
    x_user_id: Optional[str] = Header(None),
) -> str:
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated (X-User-ID header missing or invalid for test setup)",
        )
    return x_user_id


# --- NEW: Graph Service Dependency ---
def get_graph_service(
    db_conn: Neo4jConnection = Depends(get_db_conn),
) -> GraphDBService:
    """Dependency to provide an instance of GraphDBService."""
    return GraphDBService(db_connection=db_conn)


def get_sagemaker_service() -> SageMakerService:
    """Dependency to provide an instance of SageMakerService."""
    return SageMakerService()


# --- Root and DB Test Endpoints (No changes needed, but ensure db_test uses get_db_conn) ---
@app.get("/")
async def root():
    return {"message": "Hello World - Backend API is running!"}


@app.get("/db_test")
async def test_db_connection(
    db_conn_instance: Neo4jConnection = Depends(get_db_conn),
):  # Use get_db_conn
    try:
        results = db_conn_instance.query(
            "RETURN 1 AS result"
        )  # Call query on the Neo4jConnection instance
        if results and results[0]["result"] == 1:
            return {
                "status": "success",
                "message": "Connected to Neo4j AuraDB and query executed!",
            }
        else:
            return {
                "status": "failure",
                "message": "Query did not return expected result.",
                "results": results,
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")


# --- REFACTORED: create_root_interaction_node ---
@app.post(
    "/interaction-nodes/start",
    response_model=models.InteractionNode,
    status_code=status.HTTP_201_CREATED,
    tags=["Interaction Nodes"],
)
async def create_root_interaction_node_endpoint(  # Renamed to avoid confusion with service method
    payload: models.RootInteractionNodeCreate,
    current_user_id: str = Depends(get_current_user_id_from_header),
    graph_svc: GraphDBService = Depends(get_graph_service),
    sagemaker_svc: SageMakerService = Depends(get_sagemaker_service),
):
    # Placeholder for LLM Interaction - this part remains in the API layer for now
    # In a more complex app, this might also be a separate service.
    # llm_response_text = f"This is a placeholder LLM response to your prompt: '{payload.user_prompt}' for user {current_user_id}"

    try:
        # Call the graph service to create the node
        print(f"Invoking SageMaker endpoint for prompt: '{payload.user_prompt}'")
        llm_response_text = sagemaker_svc.generate_text(payload.user_prompt)
        print("Successfully received response from SageMaker.")

        created_node = await graph_svc.create_root_interaction_node(
            user_id=current_user_id,
            user_prompt=payload.user_prompt,
            summary_title=payload.summary_title,
            llm_response=llm_response_text,  # Pass the LLM response
        )
        return created_node
    except Exception as e:
        # Catch exceptions from the service layer (e.g., database errors)
        print(f"API Error: Failed to create root interaction node: {e}")
        # You might want to inspect 'e' to return more specific HTTP errors
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while creating the root interaction node: {str(e)}",
        )


# --- REFACTORED: create_branched_interaction_node ---
@app.post(
    "/interaction-nodes/{parent_node_id}/branch",
    response_model=models.InteractionNode,
    status_code=status.HTTP_201_CREATED,
    tags=["Interaction Nodes"],
)
async def create_branched_interaction_node_endpoint(  # Renamed
    parent_node_id: str,
    payload: models.InteractionNodeCreate,
    current_user_id: str = Depends(get_current_user_id_from_header),
    graph_svc: GraphDBService = Depends(get_graph_service),
    sagemaker_svc: SageMakerService = Depends(get_sagemaker_service),
):
    # Placeholder LLM call
    # llm_response_text = f"Placeholder LLM response for branch from {parent_node_id} to '{payload.user_prompt}' by {current_user_id}"

    try:
        print(f"Invoking SageMaker endpoint for branch prompt: '{payload.user_prompt}'")
        llm_response_text = sagemaker_svc.generate_text(payload.user_prompt)
        print("Successfully received response from SageMaker.")

        branched_node = await graph_svc.create_branched_interaction_node(
            parent_node_id=parent_node_id,
            user_id=current_user_id,
            user_prompt=payload.user_prompt,
            summary_title=payload.summary_title,
            llm_response=llm_response_text,
        )
        return branched_node
    except (
        ValueError
    ) as ve:  # Catch the specific ValueError for parent not found/accessible
        print(f"API Error: Parent node issue for branching: {ve}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,  # Or 403 if it's an auth issue on parent
            detail=str(ve),
        )
    except Exception as e:
        print(f"API Error: Failed to create branched interaction node: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while creating the branch: {str(e)}",
        )


# --- REFACTORED: get_interaction_node_by_id ---
@app.get(
    "/interaction-nodes/{node_id}",
    response_model=models.InteractionNode,  # Optional[models.InteractionNode] if service can return None
    status_code=status.HTTP_200_OK,
    tags=["Interaction Nodes"],
)
async def get_interaction_node_by_id_endpoint(  # Renamed
    node_id: str,
    current_user_id: str = Depends(get_current_user_id_from_header),
    graph_svc: GraphDBService = Depends(get_graph_service),
):
    try:
        node = await graph_svc.get_interaction_node_by_id(
            node_id=node_id, user_id=current_user_id
        )
        if node is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"InteractionNode with ID '{node_id}' not found or not owned by user.",
            )
        return node
    except HTTPException:  # Re-raise 404
        raise
    except Exception as e:
        print(f"API Error: Failed to get interaction node {node_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while retrieving InteractionNode '{node_id}'.",
        )


@app.get(
    "/interaction-nodes/{start_node_id}/graph",
    response_model=models.GraphData,
    status_code=status.HTTP_200_OK,
    tags=["Interaction Nodes"],
)
async def get_interaction_graph_endpoint(
    start_node_id: str,
    current_user_id: str = Depends(get_current_user_id_from_header),
    graph_svc: GraphDBService = Depends(get_graph_service),
):
    """
    Retrieves the entire explorable graph (nodes and relationships) starting
    from the given start_node_id, ensuring all elements belong to the
    authenticated user.
    """
    try:
        graph_data = await graph_svc.get_interaction_graph(  # <--- CORRECTED
            start_node_id=start_node_id, user_id=current_user_id
        )
        if graph_data is None:
            # This implies the start_node_id itself was not found or not owned by the user
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Start node with ID '{start_node_id}' not found or not owned by user.",
            )
        # If graph_data.nodes is empty but graph_data is not None, it means the start node was found
        # but had no connected path (e.g., an isolated node). This is a valid graph.
        return graph_data
    except HTTPException:  # Re-raise 404
        raise
    except Exception as e:
        print(
            f"API Error: Failed to get interaction graph for start_node {start_node_id}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while retrieving the interaction graph: {str(e)}",
        )


# --- Mangum Handler (no changes needed) ---
from mangum import Mangum

handler = Mangum(app, lifespan="on")
