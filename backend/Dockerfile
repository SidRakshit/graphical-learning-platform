# backend/Dockerfile

# Use an official AWS public ECR base image for Python 3.11 Lambda functions
# You can choose other Python versions like 3.8, 3.9, 3.10, 3.12 if available and preferred
FROM public.ecr.aws/lambda/python:3.11

# Set the working directory in the container
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy the requirements file into the container
# (Ensure you have a requirements.txt file in your backend directory)
COPY requirements.txt .

# Install Python dependencies
# --no-cache-dir reduces image size. --upgrade pip is good practice.
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy your application code (main.py, db.py, models.py, etc.) into the container
COPY . .
# If you have subdirectories like 'app/', ensure they are copied correctly, e.g., COPY app/ ./app/

# Set the command that Lambda will run.
# For FastAPI with Mangum, this will be your main.py and the FastAPI app instance.
# Mangum will adapt the FastAPI app 'app' from the 'main' module.
# The Lambda function handler in AWS will be set to this image, not a specific handler string.
CMD [ "main.handler" ]