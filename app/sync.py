import datetime
import logging

from geoalchemy2.elements import WKTElement
from sqlalchemy.orm import Session

from .config import settings
from .database import get_session
from .foursquare import FoursquareClient
from .models import Checkin, SyncState, Venue

logger = logging.getLogger(__name__)


def _parse_venue(venue_data: dict) -> dict:
    location = venue_data.get("location", {})
    categories = venue_data.get("categories", [])
    primary = categories[0] if categories else {}

    return {
        "id": venue_data["id"],
        "name": venue_data["name"],
        "lat": location.get("lat"),
        "lng": location.get("lng"),
        "address": location.get("address"),
        "city": location.get("city"),
        "state": location.get("state"),
        "country": location.get("country"),
        "postal_code": location.get("postalCode"),
        "category_id": primary.get("id"),
        "category_name": primary.get("name"),
        "raw_json": venue_data,
    }


def _parse_checkin(item: dict) -> dict:
    score_data = item.get("score")
    return {
        "id": item["id"],
        "venue_id": item.get("venue", {}).get("id"),
        "created_at": datetime.datetime.utcfromtimestamp(item["createdAt"]),
        "timezone_offset": item.get("timeZoneOffset"),
        "shout": item.get("shout"),
        "score": score_data.get("total") if score_data else None,
        "raw_json": item,
    }


def _upsert_venue(session: Session, venue_data: dict) -> None:
    parsed = _parse_venue(venue_data)
    venue = session.get(Venue, parsed["id"])

    if venue is None:
        venue = Venue(**parsed)
        if parsed["lat"] is not None and parsed["lng"] is not None:
            venue.location = WKTElement(f"POINT({parsed['lng']} {parsed['lat']})", srid=4326)
        session.add(venue)
    else:
        for k, v in parsed.items():
            setattr(venue, k, v)
        if parsed["lat"] is not None and parsed["lng"] is not None:
            venue.location = WKTElement(f"POINT({parsed['lng']} {parsed['lat']})", srid=4326)
        venue.updated_at = datetime.datetime.utcnow()


def _upsert_checkin(session: Session, item: dict) -> None:
    parsed = _parse_checkin(item)

    checkin = session.get(Checkin, parsed["id"])
    if checkin is None:
        checkin = Checkin(**parsed)
        session.add(checkin)
    else:
        for k, v in parsed.items():
            setattr(checkin, k, v)

    if item.get("venue"):
        _upsert_venue(session, item["venue"])


def _get_or_create_sync_state(session: Session) -> SyncState:
    state = session.query(SyncState).first()
    if state is None:
        state = SyncState(total_synced=0)
        session.add(state)
        session.commit()
    return state


def run_sync() -> None:
    with FoursquareClient() as client:
        session = get_session()
        try:
            state = _get_or_create_sync_state(session)

            after_timestamp = state.last_checkin_timestamp
            if after_timestamp is None:
                logger.info("No previous sync found — performing full sync.")
            else:
                logger.info(
                    "Incremental sync from timestamp %d (%s).",
                    after_timestamp,
                    datetime.datetime.utcfromtimestamp(after_timestamp).isoformat(),
                )

            count = 0
            newest_timestamp = after_timestamp or 0

            for item in client.iter_all_checkins(after_timestamp=after_timestamp):
                _upsert_checkin(session, item)
                count += 1

                ts = item["createdAt"]
                if ts > newest_timestamp:
                    newest_timestamp = ts

                if count % settings.sync_commit_interval == 0:
                    session.commit()
                    logger.info("Progress: %d checkins synced.", count)

            session.commit()

            state.last_sync_at = datetime.datetime.utcnow()
            if newest_timestamp:
                state.last_checkin_timestamp = newest_timestamp
            state.total_synced = (state.total_synced or 0) + count
            session.commit()

            logger.info("Sync complete. %d new checkins. Total in DB: %d.", count, state.total_synced)

        except Exception:
            session.rollback()
            raise
        finally:
            session.close()
