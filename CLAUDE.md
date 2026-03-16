# Swarm Checkins Database

## What this is
A Python script that mirrors Foursquare/Swarm checkin data into a PostgreSQL database. It runs as a one-shot job (not a web service).

## Tech decisions
- Python (no web framework — plain script entry point)
- SQLAlchemy + Alembic for database, httpx for HTTP
- PostgreSQL with PostGIS + GeoAlchemy2
- Docker containers, deploying to Azure Container Apps
- Azure Container Registry for images
- Bicep for infrastructure (infra/)

## Foursquare API
- Uses v2 API: GET /v2/users/self/checkins
- OAuth2 user token for auth
- Pagination via offset/limit (max 250)
- Incremental sync via afterTimestamp

## Architecture
- Full sync on first run, incremental after that
- Store raw JSON alongside parsed fields
- Tables: `checkins`, `venues`, `sync_state`
- `sync_state` tracks last sync timestamp to enable incremental syncs