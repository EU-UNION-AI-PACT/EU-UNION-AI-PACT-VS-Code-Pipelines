FROM python:3.12-alpine
RUN adduser -D -u 1000 sandbox
WORKDIR /home/sandbox
USER sandbox
COPY sandbox_app.py .
EXPOSE 8600
ENV PYTHONDONTWRITEBYTECODE=1
CMD ["python","sandbox_app.py"]
