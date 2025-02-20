# Use a minimal Python base image
FROM python:3.9-slim

# Install system dependencies (Tesseract for OCR)
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    libtesseract-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy and install dependencies first (for better Docker caching)
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . /app

# Expose the port (good practice)
EXPOSE 8000

# Start FastAPI with the correct host and port for Railway
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
