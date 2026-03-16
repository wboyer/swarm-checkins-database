FROM python:3.12-slim

WORKDIR /app

# libpq-dev provides pg_config, which is required to build psycopg2, 
# and gcc is needed to compile psycopg2.
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "-m", "app.main"]
