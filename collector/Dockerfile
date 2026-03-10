# Base Python image for the InfraGuardian collector
FROM python:3.11-slim

# Avoid .pyc files and force unbuffered logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Copy dependency list first to improve Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the collector source code
COPY collector.py .

# Start the collector when the container launches
CMD ["python", "collector.py"]
