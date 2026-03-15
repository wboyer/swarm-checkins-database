from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    foursquare_token: str
    foursquare_api_version: str = "20231201"
    database_url: str
    sync_batch_size: int = 250
    sync_commit_interval: int = 50

    class Config:
        env_file = ".env"


settings = Settings()
