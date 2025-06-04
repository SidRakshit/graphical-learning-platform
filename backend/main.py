# backend/main.py
from fastapi import FastAPI, HTTPException, Depends
from contextlib import asynccontextmanager

# Import from your db.py file
from .db import get_db_connection, close_db_connection, Neo4jConnection

# Lifespan manager for application startup and shutdown events
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize DB connection
    print("Application startup: Attempting to initialize database connection...")
    try:
        get_db_connection() # This will initialize the global driver in db.py
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

app = FastAPI(lifespan=lifespan) # Use the lifespan manager

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
            return {"status": "success", "message": "Connected to Neo4j AuraDB and query executed!"}
        else:
            return {"status": "failure", "message": "Query did not return expected result.", "results": results}
    except Exception as e:
        # If any exception occurs during the DB query
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")