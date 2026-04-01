from datetime import datetime
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings, get_settings
from app.db.models import NewsSourceRecord
from app.schemas.news import NewsSourceInfo
from app.services.source_catalog import default_source_catalog


class SourceRegistryService:
    """Source registry backed by Postgres."""

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        settings: Settings | None = None,
    ) -> None:
        self._session_factory = session_factory
        self._settings = settings or get_settings()

    async def initialize_defaults(self) -> None:
        """Ensure default source catalog exists and is in sync with settings."""
        defaults = default_source_catalog(self._settings)
        default_ids = {source.id for source in defaults}
        optional_api_source_ids = {"newsapi", "gnews"}

        async with self._session_factory() as session:
            existing_rows = await session.execute(select(NewsSourceRecord))
            existing_by_id = {row.id: row for row in existing_rows.scalars().all()}

            for source_id in optional_api_source_ids:
                row = existing_by_id.get(source_id)
                if row is not None and source_id not in default_ids:
                    row.enabled = False
                    row.configured = False

            for source in defaults:
                row = existing_by_id.get(source.id)
                if row is None:
                    session.add(
                        NewsSourceRecord(
                            id=source.id,
                            name=source.name,
                            type=source.type,
                            country=source.country,
                            enabled=source.enabled,
                            requires_api_key=source.requires_api_key,
                            configured=source.configured,
                            feed_url=source.feed_url,
                            api_base_url=source.api_base_url,
                            poll_interval_sec=source.poll_interval_sec,
                            last_run_at=source.last_run_at,
                            notes=source.notes,
                        )
                    )
                    continue

                row.name = source.name
                row.type = source.type
                row.country = source.country
                row.requires_api_key = source.requires_api_key
                row.feed_url = source.feed_url
                row.api_base_url = source.api_base_url
                row.poll_interval_sec = source.poll_interval_sec
                row.notes = source.notes

                # API-key sources mirror runtime configuration from settings.
                if source.requires_api_key:
                    row.configured = source.configured
                    row.enabled = source.enabled

            await session.commit()

    async def list_sources(self) -> List[NewsSourceInfo]:
        async with self._session_factory() as session:
            result = await session.execute(select(NewsSourceRecord).order_by(NewsSourceRecord.id))
            return [self._to_schema(row) for row in result.scalars().all()]

    async def list_active_sources(self) -> List[NewsSourceInfo]:
        async with self._session_factory() as session:
            result = await session.execute(
                select(NewsSourceRecord)
                .where(
                    NewsSourceRecord.enabled.is_(True),
                    NewsSourceRecord.configured.is_(True),
                )
                .order_by(NewsSourceRecord.id)
            )
            return [self._to_schema(row) for row in result.scalars().all()]

    async def get_source(self, source_id: str) -> Optional[NewsSourceInfo]:
        async with self._session_factory() as session:
            row = await session.get(NewsSourceRecord, source_id)
            if row is None:
                return None
            return self._to_schema(row)

    async def mark_source_run(self, source_id: str) -> None:
        async with self._session_factory() as session:
            row = await session.get(NewsSourceRecord, source_id)
            if row is None:
                return
            row.last_run_at = datetime.utcnow()
            await session.commit()

    def _to_schema(self, row: NewsSourceRecord) -> NewsSourceInfo:
        return NewsSourceInfo(
            id=row.id,
            name=row.name,
            type=row.type,
            country=row.country,
            enabled=row.enabled,
            requires_api_key=row.requires_api_key,
            configured=row.configured,
            feed_url=row.feed_url,
            api_base_url=row.api_base_url,
            poll_interval_sec=row.poll_interval_sec,
            last_run_at=row.last_run_at,
            notes=row.notes,
        )
