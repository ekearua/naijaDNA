from functools import lru_cache
from pathlib import Path
from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


ENV_FILE = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    """Application settings loaded from environment and `.env`."""

    app_name: str = "NaijaPulse API"
    app_version: str = "0.1.0"
    environment: str = "dev"
    debug: bool = True
    api_prefix: str = "/api/v1"
    enable_ingestion_scheduler: bool = True
    run_ingestion_on_startup: bool = True
    ingestion_startup_timeout_seconds: int = 20
    ingestion_startup_limit_per_source: int = 10
    ingestion_interval_seconds: int = 900
    ingestion_default_limit_per_source: int = 50
    ingestion_max_recent_runs: int = 25
    database_url: str = (
        "postgresql+asyncpg://postgres:your_postgres_password@localhost:5432/naijapulse"
    )
    database_echo: bool = False
    newsapi_api_key: str = ""
    gnews_api_key: str = ""
    enable_rss_sources: bool = True
    enable_newsapi_source: bool = False
    enable_gnews_source: bool = False
    auth_token_secret: str = "change-me-in-env"
    auth_access_token_ttl_seconds: int = 60 * 60 * 24 * 7
    stream_viewer_presence_ttl_seconds: int = 75
    livekit_url: str = ""
    livekit_api_key: str = ""
    livekit_api_secret: str = ""
    livekit_token_ttl_seconds: int = 60 * 60
    upstash_redis_rest_url: str = ""
    upstash_redis_rest_token: str = ""
    response_cache_enabled: bool = True
    cache_news_top_ttl_seconds: int = 900
    cache_news_latest_ttl_seconds: int = 900
    cache_polls_active_ttl_seconds: int = 900
    cache_categories_ttl_seconds: int = 21600
    cache_tags_ttl_seconds: int = 21600
    cors_origins: List[str] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://localhost:5173",
            "http://localhost:8080",
            "http://localhost:7357",
            "http://127.0.0.1:7357",
        ]
    )

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @field_validator("debug", mode="before")
    @classmethod
    def _coerce_debug(cls, value):  # type: ignore[override]
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"1", "true", "yes", "on", "debug", "dev"}:
                return True
            if normalized in {
                "0",
                "false",
                "no",
                "off",
                "release",
                "profile",
                "prod",
                "production",
            }:
                return False
        return value

    @property
    def livekit_enabled(self) -> bool:
        return all(
            (
                self.livekit_url.strip(),
                self.livekit_api_key.strip(),
                self.livekit_api_secret.strip(),
            )
        )


@lru_cache
def get_settings() -> Settings:
    """Return a cached settings instance to avoid repeated env parsing."""
    return Settings()
