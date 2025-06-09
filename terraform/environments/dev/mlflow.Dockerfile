# Start from the official MLflow base image
FROM ghcr.io/mlflow/mlflow:v2.13.0

# Install the Python library for PostgreSQL connectivity
RUN pip install psycopg2-binary