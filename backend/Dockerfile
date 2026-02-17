FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (including ffmpeg for audio processing)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run migrations then start the application
CMD alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000
