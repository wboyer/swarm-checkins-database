# Swarm Checkins Database

Mirrors Foursquare/Swarm checkin data into a personal PostgreSQL database with PostGIS support.

## Prerequisites

- Docker and Docker Compose
- A Foursquare OAuth2 user token

## Setup

Copy the example env file and fill in your token:

```bash
cp .env.example .env
```

Edit `.env`:

```
FOURSQUARE_TOKEN=your_oauth_token_here
DATABASE_URL=postgresql://swarm:swarm@db:5432/swarm_checkins
```

## Running a Sync

### One-shot sync (Docker Compose)

This starts the database, runs the sync, and exits:

```bash
docker compose up sync
```

On first run, this performs a **full sync** — fetching all checkins from the beginning. Subsequent runs are **incremental**, fetching only checkins newer than the last synced timestamp.

### Connecting to the Database

From the VS Code terminal (inside the devcontainer, where `postgresql-client` is available):

```bash
psql -h db -U swarm -d swarm_checkins
```

Or via Docker Compose from outside the devcontainer:

```bash
docker compose exec db psql -U swarm -d swarm_checkins
```

### Forcing a Full Sync

The sync mode is determined by the `sync_state` table. To force a full re-sync, clear that table:

```bash
DELETE FROM sync_state;
\q
```

Then run the sync again:

```bash
docker compose up sync
```

## Development

Start the database and a long-running dev container:

```bash
docker compose up -d dev
```

Exec into the container to run commands interactively:

```bash
docker compose exec dev bash

# Inside the container:
python -m app.main          # run a sync
alembic upgrade head        # apply migrations
alembic current             # check migration status
alembic downgrade base      # roll back all migrations
```

### Running Locally (without Docker)

Requires a PostgreSQL instance with the PostGIS extension available.

```bash
pip install -r requirements.txt

# Set env vars (or use a .env file)
export FOURSQUARE_TOKEN=your_token
export DATABASE_URL=postgresql://user:pass@localhost:5432/swarm_checkins

# Apply migrations
alembic upgrade head

# Run sync
python -m app.main
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `FOURSQUARE_TOKEN` | Yes | — | OAuth2 user token for Foursquare API v2 |
| `DATABASE_URL` | Yes | — | PostgreSQL connection string |
| `SYNC_BATCH_SIZE` | No | `250` | Checkins fetched per API request (max 250) |
| `SYNC_COMMIT_INTERVAL` | No | `50` | DB commit frequency (every N checkins) |

## Database Schema

Three tables are created by the Alembic migration:

- **`venues`** — Foursquare venue data, including a PostGIS `POINT` geometry column and full raw JSON
- **`checkins`** — Individual checkins with a foreign key to `venues` and full raw JSON
- **`sync_state`** — Single-row table tracking the last sync timestamp and total count

## Deployment

The app is designed to deploy to **Azure Container Apps** with images stored in **Azure Container Registry**. Each sync run is a one-shot container execution, run on a schedule (e.g. daily cron) rather than as a persistent service.
