# backend/main.py
from fastapi import FastAPI, HTTPException, Depends, status
from contextlib import asynccontextmanager

# Import from your db.py file
from .db import get_db_connection, close_db_connection, Neo4jConnection
from . import models  # Import your Pydantic models
import uuid  # For generating IDs


# Lifespan manager for application startup and shutdown events
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize DB connection
    print("Application startup: Attempting to initialize database connection...")
    try:
        get_db_connection()  # This will initialize the global driver in db.py
        print("Database connection initialized (or was already initialized).")
    except Exception as e:
        print(f"Application startup: Failed to initialize database: {e}")
        # Depending on your app's needs, you might want to prevent startup
        # or allow it to start in a degraded state.

    yield  # Application runs here

    # Shutdown: Close DB connection
    print("Application shutdown: Closing database connection...")
    close_db_connection()
    print("Database connection closed.")


app = FastAPI(lifespan=lifespan)  # Use the lifespan manager


# Dependency to get the DB connection
# This makes it easier to use the connection in your path operations
async def get_db() -> Neo4jConnection:
    db_conn = get_db_connection()
    if db_conn is None:
        # This might happen if initialization failed during startup
        raise HTTPException(status_code=503, detail="Database connection not available")
    return db_conn


@app.get("/")
async def root():
    return {"message": "Hello World - Backend API is running!"}


@app.get("/items/{item_id}")
async def read_item(item_id: int, q: str | None = None):
    return {"item_id": item_id, "q": q}


# New endpoint to test DB connection
@app.get("/db_test")
async def test_db_connection(db: Neo4jConnection = Depends(get_db)):
    try:
        # A very simple query to test the connection
        results = db.query("RETURN 1 AS result")
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
        # If any exception occurs during the DB query
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")


@app.post(
    "/topics/",
    response_model=models.Topic,
    status_code=status.HTTP_201_CREATED,
    tags=["Topics"],
)
async def create_topic(
    topic_data: models.TopicCreate, db: Neo4jConnection = Depends(get_db)
):
    """
    Create a new topic in the database.
    """
    # Generate a unique ID for the new topic
    topic_id = str(uuid.uuid4())

    # Prepare the Cypher query and parameters
    # We're creating a node with the Label "Topic"
    # Properties are passed as parameters to prevent Cypher injection
    query = (
        "CREATE (t:Topic {id: $id, name: $name, description: $description}) "
        "RETURN t.id AS id, t.name AS name, t.description AS description"
    )
    parameters = {
        "id": topic_id,
        "name": topic_data.name,
        "description": topic_data.description,
    }

    try:
        results = db.query(query, parameters)
        if results:
            # The query returns the properties of the created node
            created_topic_data = results[0]  # Get the first (and only) record
            # Pydantic's from_attributes (thanks to model_config) should handle the dict-like record
            return models.Topic(**created_topic_data)
        else:
            raise HTTPException(
                status_code=500,
                detail="Failed to create topic in database or no result returned.",
            )
    except Exception as e:
        # Log the exception e here in a real application
        print(f"Error creating topic: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while creating the topic: {str(e)}",
        )
