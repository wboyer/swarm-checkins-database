import datetime

from geoalchemy2 import Geometry
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(DeclarativeBase):
    pass


class Venue(Base):
    __tablename__ = "venues"

    id = Column(String, primary_key=True)  # Foursquare venue ID
    name = Column(String, nullable=False)
    lat = Column(Float)
    lng = Column(Float)
    location = Column(Geometry("POINT", srid=4326))
    address = Column(String)
    city = Column(String)
    state = Column(String)
    country = Column(String)
    postal_code = Column(String)
    category_id = Column(String)
    category_name = Column(String)
    raw_json = Column(JSONB)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    checkins = relationship("Checkin", back_populates="venue")


class Checkin(Base):
    __tablename__ = "checkins"

    id = Column(String, primary_key=True)  # Foursquare checkin ID
    venue_id = Column(String, ForeignKey("venues.id"), nullable=True)
    created_at = Column(DateTime, nullable=False)
    timezone_offset = Column(Integer)  # minutes from UTC
    shout = Column(Text)
    score = Column(Float)
    raw_json = Column(JSONB)
    synced_at = Column(DateTime, default=datetime.datetime.utcnow)

    venue = relationship("Venue", back_populates="checkins")


class SyncState(Base):
    __tablename__ = "sync_state"

    id = Column(Integer, primary_key=True)
    last_sync_at = Column(DateTime)
    last_checkin_timestamp = Column(Integer)  # Unix timestamp of most recent synced checkin
    total_synced = Column(Integer, default=0)
