# Swarm Checkins Database

## What this is
A service that mirrors Foursquare/Swarm checkin data into my own PostgreSQL database.

## Tech decisions
- Python with FastAPI
- SQLAlchemy + Alembic for database
- PostgreSQL with PostGIS
- Docker containers, deploying to Azure Container Apps
- Azure Container Registry for images

## Foursquare API
- Uses v2 API: GET /v2/users/self/checkins
- OAuth2 user token for auth
- Pagination via offset/limit (max 250)
- Incremental sync via afterTimestamp

## Architecture
- Full sync on first run, incremental after that
- Store raw JSON alongside parsed fields
- Separate tables for checkins and venues