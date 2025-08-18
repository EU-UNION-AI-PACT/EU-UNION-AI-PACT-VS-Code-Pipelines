FROM python:3.12-slim
WORKDIR /app
COPY app.py /app/app.py
RUN pip install fastapi uvicorn[standard] requests pydantic
EXPOSE 8200
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8200"]
