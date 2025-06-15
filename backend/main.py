from fastapi import FastAPI, HTTPException, Depends, status, Header
from contextlib import asynccontextmanager
from typing import List, Optional
import os  # Import os to access environment variables
from openai import OpenAI  # Import the OpenAI client

# Import from your local modules
from db import get_db_connection, close_db_connection, Neo4jConnection
import models  # Your Pydantic models from models.py
from graph_service import GraphDBService  # Import the new service

import uuid
from datetime import datetime


# --- Lifespan Manager ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Application startup: Attempting to initialize database connection...")
    try:
        conn_instance = get_db_connection()
        if conn_instance is None or not conn_instance._driver:
            print(
                "FATAL: Database driver (conn_instance._driver) not initialized during startup."
            )
            # Consider raising an error to halt app startup if DB is critical
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

# Initialize OpenAI client globally or within a dependency
# It's good practice to get the API key from environment variables
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    print(
        "WARNING: OPENAI_API_KEY environment variable not set. OpenAI API calls will fail."
    )
    # In a production environment, you might want to raise an error here
    # raise Exception("OPENAI_API_KEY environment variable not set.")

openai_client = OpenAI(api_key=OPENAI_API_KEY)


# --- Database Dependency ---
async def get_db_conn() -> Neo4jConnection:
    db_conn_instance = get_db_connection()
    if db_conn_instance is None or not db_conn_instance._driver:
        print(
            "Error in get_db_conn: Neo4jConnection instance is None or its _driver is not initialized."
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection not available or not initialized.",
        )
    return db_conn_instance


# --- Placeholder Auth Dependency ---
async def get_current_user_id_from_header(
    x_user_id: Optional[str] = Header(None),
) -> str:
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated (X-User-ID header missing or invalid for test setup)",
        )
    return x_user_id


# --- Graph Service Dependency ---
def get_graph_service(
    db_conn: Neo4jConnection = Depends(get_db_conn),
) -> GraphDBService:
    """Dependency to provide an instance of GraphDBService."""
    return GraphDBService(db_connection=db_conn)


# SageMakerService dependency removed
# def get_sagemaker_service() -> SageMakerService:
#     """Dependency to provide an instance of SageMakerService."""
#     return SageMakerService()


# --- Root and DB Test Endpoints ---
@app.get("/")
async def root():
    return {"message": "Hello World - Backend API is running!"}


@app.get("/db_test")
async def test_db_connection(
    db_conn_instance: Neo4jConnection = Depends(get_db_conn),
):
    try:
        results = db_conn_instance.query("RETURN 1 AS result")
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
async def create_root_interaction_node_endpoint(
    payload: models.RootInteractionNodeCreate,
    current_user_id: str = Depends(get_current_user_id_from_header),
    graph_svc: GraphDBService = Depends(get_graph_service),
    # sagemaker_svc: SageMakerService = Depends(get_sagemaker_service), # Removed SageMaker dependency
):
    try:
        print(f"Calling OpenAI API for prompt: '{payload.user_prompt}'")
        # Make the OpenAI API call
        chat_completion = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",  # Or your preferred OpenAI model, e.g., "gpt-4o"
            messages=[
                {
                    "role": "system",
                    "content": "You are skilled teacher. Don't jump into directly answering the questino. Identify how a user wants to learn about a topic. Ask many questions to gather more context and fully understand how a student wants to learn.",
                },
                {"role": "user", "content": payload.user_prompt},
            ],
        )
        llm_response_text = chat_completion.choices[0].message.content
        print("Successfully received response from OpenAI.")

        created_node = await graph_svc.create_root_interaction_node(
            user_id=current_user_id,
            user_prompt=payload.user_prompt,
            summary_title=payload.summary_title,
            llm_response=llm_response_text,
        )
        return created_node
    except Exception as e:
        print(f"API Error: Failed to create root interaction node: {e}")
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
async def create_branched_interaction_node_endpoint(
    parent_node_id: str,
    payload: models.InteractionNodeCreate,
    current_user_id: str = Depends(get_current_user_id_from_header),
    graph_svc: GraphDBService = Depends(get_graph_service),
    # sagemaker_svc: SageMakerService = Depends(get_sagemaker_service), # Removed SageMaker dependency
):
    try:
        print(f"Calling OpenAI API for branch prompt: '{payload.user_prompt}'")
        # Make the OpenAI API call
        chat_completion = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",  # Or your preferred OpenAI model
            messages=[
                {
                    "role": "system",
                    "content": "You are a skilled teacher. Follow the agreed learning path and method specifics by which the user wishes to learn (details, high-level overview, examples, analogies etc.). Ask questions at the end to learn more about the user and to identify which direction they which to go down.",
                },
                {"role": "user", "content": payload.user_prompt},
            ],
        )
        llm_response_text = chat_completion.choices[0].message.content
        print("Successfully received response from OpenAI.")

        branched_node = await graph_svc.create_branched_interaction_node(
            parent_node_id=parent_node_id,
            user_id=current_user_id,
            user_prompt=payload.user_prompt,
            summary_title=payload.summary_title,
            llm_response=llm_response_text,
        )
        return branched_node
    except ValueError as ve:
        print(f"API Error: Parent node issue for branching: {ve}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
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
    response_model=models.InteractionNode,
    status_code=status.HTTP_200_OK,
    tags=["Interaction Nodes"],
)
async def get_interaction_node_by_id_endpoint(
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
    except HTTPException:
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
        graph_data = await graph_svc.get_interaction_graph(
            start_node_id=start_node_id, user_id=current_user_id
        )
        if graph_data is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Start node with ID '{start_node_id}' not found or not owned by user.",
            )
        return graph_data
    except HTTPException:
        raise
    except Exception as e:
        print(
            f"API Error: Failed to get interaction graph for start_node {start_node_id}: {e}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while retrieving the interaction graph: {str(e)}",
        )


# --- Mangum Handler ---
from mangum import Mangum

handler = Mangum(app, lifespan="on")
