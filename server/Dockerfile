FROM python:3.12-slim-bookworm

WORKDIR /app

COPY server/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY server/app ./app
COPY data ./data

ENV FC_DATA_DIR=/app/data
ENV FC_DB_PATH=/data/familiarscall.db
ENV PORT=8080

EXPOSE 8080

VOLUME ["/data"]

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
