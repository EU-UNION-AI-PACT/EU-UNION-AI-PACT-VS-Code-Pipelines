FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY app.py /app/app.py
RUN pip install --no-cache-dir fastapi uvicorn[standard] psycopg2-binary pydantic requests PyYAML
EXPOSE 8100
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8100"]
