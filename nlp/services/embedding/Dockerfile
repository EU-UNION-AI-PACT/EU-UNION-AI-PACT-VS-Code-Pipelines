FROM python:3.12-slim
ENV PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY app.py /app/app.py
RUN pip install --no-cache-dir fastapi uvicorn[standard] sentence-transformers
EXPOSE 8000
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8000"]
