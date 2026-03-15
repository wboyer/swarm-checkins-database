import time
from typing import Iterator

import httpx

from .config import settings

BASE_URL = "https://api.foursquare.com/v2"
API_RATE_LIMIT_DELAY = 0.5  # seconds between paginated requests


class FoursquareClient:
    def __init__(self) -> None:
        self._client = httpx.Client(timeout=30)

    def _params(self, **kwargs) -> dict:
        return {
            "oauth_token": settings.foursquare_token,
            "v": settings.foursquare_api_version,
            **kwargs,
        }

    def _get_checkins_page(self, limit: int, offset: int, after_timestamp: int | None) -> dict:
        params = self._params(limit=limit, offset=offset, sort="oldestfirst")
        if after_timestamp is not None:
            params["afterTimestamp"] = after_timestamp

        response = self._client.get(f"{BASE_URL}/users/self/checkins", params=params)
        response.raise_for_status()
        data = response.json()

        if data["meta"]["code"] != 200:
            raise RuntimeError(f"Foursquare API error: {data['meta']}")

        return data["response"]["checkins"]

    def iter_all_checkins(self, after_timestamp: int | None = None) -> Iterator[dict]:
        """Yield every checkin, oldest-first, handling pagination automatically."""
        offset = 0
        limit = settings.sync_batch_size

        while True:
            page = self._get_checkins_page(limit=limit, offset=offset, after_timestamp=after_timestamp)
            items = page["items"]

            if not items:
                break

            yield from items

            offset += len(items)
            if offset >= page["count"]:
                break

            time.sleep(API_RATE_LIMIT_DELAY)

    def close(self) -> None:
        self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
