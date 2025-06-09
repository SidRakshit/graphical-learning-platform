# backend/db.py
import os
import json
import boto3
from neo4j import GraphDatabase, basic_auth
from botocore.exceptions import ClientError

# --- Configuration for Secrets Manager ---
# You should have this ARN from your Terraform output (auradb_credentials_secret_arn)
# For local development, you could set this as an environment variable
# or for now, you can temporarily hardcode it here for testing,
# but ideally, it comes from an environment variable or a config system.
# SECRET_NAME_OR_ARN = os.environ.get("AURADB_SECRET_ARN", "YOUR_AURADB_SECRET_ARN_HERE")
# AWS_REGION_NAME = os.environ.get("AWS_REGION", "us-east-1") # Ensure this is your AWS region

SECRET_NAME_OR_ARN = os.environ.get("AURADB_SECRET_ARN")
AWS_REGION_NAME = os.environ.get("AWS_REGION")


# --- Global Neo4j Driver Variable ---
# We'll initialize this when the application starts
driver = None


class Neo4jConnection:
    def __init__(self, uri, user, password):
        # Initialize the Neo4j driver
        # This driver instance is thread-safe and typically created once per application
        self._driver = GraphDatabase.driver(uri, auth=basic_auth(user, password))

    def close(self):
        if self._driver is not None:
            self._driver.close()

    def query(self, query, parameters=None, db=None):
        assert self._driver is not None, "Driver not initialized!"
        session = None
        response = None
        try:
            session = (
                self._driver.session(database=db)
                if db is not None
                else self._driver.session()
            )
            response = list(session.run(query, parameters))
        except Exception as e:
            print(f"Query failed: {e}")
            # You might want to raise the exception or handle it more gracefully
            raise
        finally:
            if session is not None:
                session.close()
        return response


def get_auradb_credentials_from_secrets_manager(secret_name_or_arn, region_name):
    """Retrieves Neo4j AuraDB credentials from AWS Secrets Manager."""
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)

    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name_or_arn)
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        print(f"Error retrieving secret: {e}")
        raise e  # Reraise the exception to handle it in the calling code

    # Decrypts secret using the associated KMS key.
    # Depending on whether the secret is a string or binary, one of these fields will be populated.
    if "SecretString" in get_secret_value_response:
        secret = get_secret_value_response["SecretString"]
        return json.loads(secret)  # Our secret is stored as a JSON string
    else:
        # Handle binary secret if necessary, though we stored ours as JSON string
        # decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
        raise ValueError("SecretString not found in AWS Secrets Manager response.")


def get_db_connection():
    """
    Initializes and returns a Neo4jConnection instance.
    This function will be called to get a DB connection object.
    """
    global driver  # Use the global driver variable
    if driver is None:
        print("Initializing Neo4j driver...")
        try:
            creds = get_auradb_credentials_from_secrets_manager(
                SECRET_NAME_OR_ARN, AWS_REGION_NAME
            )
            uri = creds.get("uri")
            user = creds.get("username")
            password = creds.get("password")

            if not all([uri, user, password]):
                raise ValueError(
                    "Missing one or more credentials (uri, username, password) from Secrets Manager."
                )

            # Create the Neo4jConnection instance which initializes the driver
            driver = Neo4jConnection(uri, user, password)
            print("Neo4j driver initialized successfully.")
        except Exception as e:
            print(f"Failed to initialize Neo4j driver: {e}")
            # In a real app, you might want to implement retries or more robust error handling
            driver = None  # Ensure driver is None if initialization fails
            raise  # Reraise the exception so the app knows initialization failed
    return driver


def close_db_connection():
    """Closes the Neo4j driver connection."""
    global driver
    if driver is not None:
        print("Closing Neo4j driver connection...")
        driver.close()
        driver = None
        print("Neo4j driver connection closed.")
