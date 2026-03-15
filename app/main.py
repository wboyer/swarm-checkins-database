import logging
import sys

from .database import init_db
from .sync import run_sync

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


def main() -> None:
    logger.info("Initializing database schema.")
    init_db()

    logger.info("Starting Foursquare checkin sync.")
    run_sync()

    logger.info("Done.")


if __name__ == "__main__":
    main()
