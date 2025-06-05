# backend/main.py
from fastapi import FastAPI, HTTPException, Depends, status
from contextlib import asynccontextmanager

# Import from your db.py file
from .db import get_db_connection, close_db_connection, Neo4jConnection
from . import models  # Import your Pydantic models
import uuid  # For generating IDs
from typing import List
from mangum import Mangum


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


@app.get("/topics/{topic_id}", response_model=models.Topic, tags=["Topics"])
async def get_topic(topic_id: str, db: Neo4jConnection = Depends(get_db)):
    """
    Retrieve a specific topic by its ID.
    """
    query = (
        "MATCH (t:Topic {id: $topic_id}) "
        "RETURN t.id AS id, t.name AS name, t.description AS description"
    )
    parameters = {"topic_id": topic_id}

    try:
        results = db.query(query, parameters)
        if results:
            # Pydantic's from_attributes should handle the dict-like record
            return models.Topic(**results[0])
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Topic not found"
            )
    except HTTPException:
        raise  # Re-raise HTTPException directly
    except Exception as e:
        # Log the exception e here in a real application
        print(f"Error retrieving topic: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while retrieving the topic: {str(e)}",
        )


@app.get("/topics/", response_model=List[models.Topic], tags=["Topics"])
async def get_all_topics(db: Neo4jConnection = Depends(get_db)):
    """
    Retrieve all topics from the database, ordered by name.
    """
    query = (
        "MATCH (t:Topic) "
        "RETURN t.id AS id, t.name AS name, t.description AS description "
        "ORDER BY t.name"  # Ordering results by name for consistency
    )

    try:
        results = db.query(query)
        topics = []
        if results:
            for record in results:
                # Pydantic's from_attributes should handle the dict-like record
                topics.append(models.Topic(**record))
        return topics
    except Exception as e:
        # Log the exception e here in a real application
        print(f"Error retrieving all topics: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while retrieving topics: {str(e)}",
        )


@app.put("/topics/{topic_id}", response_model=models.Topic, tags=["Topics"])
async def update_topic(
    topic_id: str,
    topic_update_data: models.TopicUpdate,
    db: Neo4jConnection = Depends(get_db),
):
    """
    Update an existing topic by its ID.
    Only fields provided in the request body will be updated.
    """
    # Convert the Pydantic model to a dictionary, excluding unset fields
    # This ensures we only try to update fields that were actually provided in the request
    update_fields = topic_update_data.model_dump(exclude_unset=True)

    if not update_fields:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="No update fields provided."
        )

    # Build the SET part of the Cypher query dynamically
    # This is safer and cleaner than string formatting directly into the query.
    # Example: SET t.name = $name, t.description = $description
    set_clauses = [f"t.{key} = ${key}" for key in update_fields.keys()]
    set_query_part = ", ".join(set_clauses)

    query = (
        f"MATCH (t:Topic {{id: $topic_id}}) "
        f"SET {set_query_part} "
        "RETURN t.id AS id, t.name AS name, t.description AS description"
    )

    parameters = {"topic_id": topic_id, **update_fields}

    try:
        results = db.query(query, parameters)
        if results:
            # Pydantic's from_attributes should handle the dict-like record
            return models.Topic(**results[0])
        else:
            # This means the MATCH clause didn't find the topic
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Topic not found to update.",
            )
    except HTTPException:
        raise  # Re-raise HTTPException directly
    except Exception as e:
        print(f"Error updating topic: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while updating the topic: {str(e)}",
        )


@app.delete(
    "/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Topics"]
)
async def delete_topic(topic_id: str, db: Neo4jConnection = Depends(get_db)):
    """
    Delete a topic by its ID.
    If the topic exists, it will be deleted.
    If the topic does not exist, a 404 error will be returned.
    """
    # First, check if the topic exists to provide a proper 404 if not.
    # Then, delete it. We can do this in a way that returns information about the deletion.
    # This query attempts to match the node, then uses a WITH clause to pass the node
    # (if found) to the DETACH DELETE part. It returns the count of nodes found *before* deletion.
    query = (
        "MATCH (t:Topic {id: $topic_id}) "
        "WITH t, count(t) AS nodes_found "  # Count matching nodes
        "WHERE nodes_found > 0 "  # Proceed only if node was found
        "DETACH DELETE t "  # Delete the node and its relationships
        "RETURN nodes_found"  # Return the original count
    )
    # If the node doesn't exist initially, the MATCH will find nothing,
    # nodes_found will effectively be 0 for that non-existent node path,
    # and DETACH DELETE won't run. We need a way to return 0 if not found.

    # A slightly different approach to ensure we know if it was found:
    # 1. Try to match.
    # 2. If matched, then detach delete.
    # We can use the summary information from the driver, or structure the query carefully.

    # Let's use a query that conditionally deletes and tells us if it did.
    # This query will return the ID if deleted, or null if not found.
    query_delete_and_check = (
        "MATCH (t:Topic {id: $topic_id}) "
        "DETACH DELETE t "
        "RETURN t.id AS deleted_id"  # This will only return if a node was actually deleted
        # and t was bound before deletion.
        # However, after DELETE, 't' is gone.
        # A better way for Neo4j 4.x+ is to return a count from delete.
        # Let's try to get a summary or a conditional return.
        # Simpler for now: Try to delete. If the node doesn't exist, DETACH DELETE does nothing.
        # We need to check if it existed *before* trying to delete for a clean 404.
    )

    # Approach: 1. Check existence. 2. If exists, delete.
    check_query = "MATCH (t:Topic {id: $topic_id}) RETURN count(t) AS count"
    delete_query = "MATCH (t:Topic {id: $topic_id}) DETACH DELETE t"
    parameters = {"topic_id": topic_id}

    try:
        # Check if topic exists
        check_results = db.query(check_query, parameters)
        if not check_results or check_results[0]["count"] == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Topic not found to delete.",
            )

        # If it exists, delete it
        # The DETACH DELETE query doesn't return rows, so db.query() will return an empty list.
        # We rely on it not throwing an error if successful.
        db.query(delete_query, parameters)

        # If delete was successful, FastAPI automatically returns 204 No Content
        # because the function doesn't explicitly return a body and status_code is 204.
        return None  # Explicitly return None for 204

    except HTTPException:
        raise  # Re-raise HTTPException directly (like our 404)
    except Exception as e:
        print(f"Error deleting topic: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while deleting the topic: {str(e)}",
        )


handler = Mangum(app, lifespan="on")
