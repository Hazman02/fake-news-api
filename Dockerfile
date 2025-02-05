# Use an official minimal Python base image
FROM python:3.9-slim

# Install system dependencies including Tesseract
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    libtesseract-dev \
    && rm -rf /var/lib/apt/lists/*

# Set a working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt /app

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your code
COPY . /app

# Expose port 8000 (not strictly necessary, but good practice)
EXPOSE 8000

# Final command to run your FastAPI app
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
