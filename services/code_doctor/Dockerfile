FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY services/code_doctor /app/services/code_doctor

# Create ledger directory
RUN mkdir -p /app/code-doctor-ledger

# Set environment variables
ENV CODE_DOCTOR_LEDGER=/app/code-doctor-ledger
ENV PYTHONPATH=/app

EXPOSE 8500

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8500/healthz || exit 1

CMD ["uvicorn", "services.code_doctor.app:app", "--host", "0.0.0.0", "--port", "8500"]
