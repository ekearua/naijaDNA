import asyncio
from collections import deque
from datetime import datetime
from typing import Deque, Dict, List, Literal, Optional
from uuid import uuid4

from app.core.config import get_settings
from app.integrations.news_sources.base import NewsSourceAdapter
from app.integrations.news_sources.gnews_adapter import GNewsNewsSourceAdapter
from app.integrations.news_sources.newsapi_adapter import NewsApiNewsSourceAdapter
from app.integrations.news_sources.rss_adapter import RssNewsSourceAdapter
from app.schemas.ingestion import (
    IngestionRunRecord,
    IngestionStatusResponse,
    SourceIngestionResult,
)
from app.schemas.news import NewsSourceInfo
from app.services.news_service import NewsService
from app.services.response_cache_service import ResponseCacheService
from app.services.source_registry_service import SourceRegistryService


class IngestionAlreadyRunningError(Exception):
    pass


class IngestionPipelineService:
    """Coordinates fetch -> dedupe/ingest -> run-metrics reporting."""

    def __init__(
        self,
        *,
        news_service: NewsService,
        source_registry_service: SourceRegistryService,
        response_cache_service: ResponseCacheService | None = None,
        max_recent_runs: int = 25,
        default_limit_per_source: int = 25,
    ) -> None:
        self._news_service = news_service
        self._source_registry_service = source_registry_service
        self._response_cache_service = response_cache_service
        self._default_limit_per_source = default_limit_per_source
        self._run_lock = asyncio.Lock()
        self._is_running = False
        self._latest_run: Optional[IngestionRunRecord] = None
        self._runs: Deque[IngestionRunRecord] = deque(maxlen=max_recent_runs)
        settings = get_settings()

        # Type-level adapters handle generic source categories like RSS.
        self._adapters_by_type: Dict[str, NewsSourceAdapter] = {
            "rss": RssNewsSourceAdapter(),
            "publisher_rss": RssNewsSourceAdapter(),
        }
        # Source-level adapters let different providers share a common type.
        self._adapters_by_id: Dict[str, NewsSourceAdapter] = {
            "newsapi": NewsApiNewsSourceAdapter(api_key=settings.newsapi_api_key),
            "gnews": GNewsNewsSourceAdapter(api_key=settings.gnews_api_key),
        }

    async def run_manual(
        self,
        *,
        source_ids: Optional[List[str]] = None,
        limit_per_source: Optional[int] = None,
    ) -> IngestionRunRecord:
        return await self._run(
            triggered_by="manual",
            source_ids=source_ids,
            limit_per_source=limit_per_source,
        )

    async def run_scheduled(self) -> IngestionRunRecord:
        return await self._run(triggered_by="scheduler")

    async def get_status(self) -> IngestionStatusResponse:
        """Return runtime status and recent run history for admin visibility."""
        sources = await self._source_registry_service.list_sources()
        active_sources = [source for source in sources if source.enabled and source.configured]
        return IngestionStatusResponse(
            running=self._is_running,
            last_run=self._latest_run,
            recent_runs=list(self._runs),
            total_sources=len(sources),
            active_sources=len(active_sources),
        )

    async def _run(
        self,
        *,
        triggered_by: Literal["manual", "scheduler"],
        source_ids: Optional[List[str]] = None,
        limit_per_source: Optional[int] = None,
    ) -> IngestionRunRecord:
        async with self._run_lock:
            # Reject overlapping runs so metrics and dedupe counters stay coherent.
            if self._is_running:
                raise IngestionAlreadyRunningError("Ingestion run is already in progress.")
            self._is_running = True

        run = IngestionRunRecord(
            run_id=str(uuid4()),
            triggered_by=triggered_by,
            started_at=datetime.utcnow(),
            status="running",
        )

        try:
            selected_sources = await self._resolve_sources(source_ids)
            source_limit = limit_per_source or self._default_limit_per_source

            if not selected_sources:
                run.status = "failed"
                run.finished_at = datetime.utcnow()
                run.error_count = 1
                run.sources.append(
                    SourceIngestionResult(
                        source_id="none",
                        source_name="No eligible sources",
                        status="failed",
                        errors=["No configured and enabled sources were found."],
                    )
                )
                self._register_run(run)
                return run

            source_results: List[SourceIngestionResult] = []
            for source in selected_sources:
                # Sequential execution keeps memory and source pressure predictable.
                source_result = await self._run_source(source=source, limit=source_limit)
                source_results.append(source_result)

            run.sources = source_results
            run.fetched_count = sum(result.fetched for result in source_results)
            run.inserted_count = sum(result.inserted for result in source_results)
            run.deduped_count = sum(result.deduped for result in source_results)
            run.error_count = sum(len(result.errors) for result in source_results)
            run.finished_at = datetime.utcnow()
            run.status = self._resolve_run_status(source_results)
            if run.inserted_count > 0 and self._response_cache_service is not None:
                await self._response_cache_service.invalidate_namespace("news")
            self._register_run(run)
            return run
        finally:
            self._is_running = False

    async def _resolve_sources(self, source_ids: Optional[List[str]]) -> List[NewsSourceInfo]:
        if source_ids:
            sources: List[NewsSourceInfo] = []
            for source_id in source_ids:
                source = await self._source_registry_service.get_source(source_id)
                if source and source.enabled and source.configured:
                    sources.append(source)
            return sources
        return await self._source_registry_service.list_active_sources()

    async def _run_source(
        self,
        *,
        source: NewsSourceInfo,
        limit: int,
    ) -> SourceIngestionResult:
        adapter = self._resolve_adapter(source)
        if adapter is None:
            return SourceIngestionResult(
                source_id=source.id,
                source_name=source.name,
                status="skipped",
                errors=[f"No adapter configured for source type '{source.type}'."],
            )

        try:
            fetched_articles = await adapter.fetch_latest(source=source, limit=limit)
            inserted, deduped = await self._news_service.ingest_articles(fetched_articles)
            # Track run timestamp for operational debugging and source health checks.
            await self._source_registry_service.mark_source_run(source.id)

            return SourceIngestionResult(
                source_id=source.id,
                source_name=source.name,
                status="success",
                fetched=len(fetched_articles),
                inserted=inserted,
                deduped=deduped,
            )
        except asyncio.CancelledError:
            # Propagate task cancellation so startup timeout can interrupt ingestion cleanly.
            raise
        except Exception as exc:  # noqa: BLE001
            return SourceIngestionResult(
                source_id=source.id,
                source_name=source.name,
                status="failed",
                errors=[str(exc)],
            )

    def _resolve_adapter(self, source: NewsSourceInfo) -> Optional[NewsSourceAdapter]:
        # Prefer source-specific adapters before falling back to type defaults.
        if source.id in self._adapters_by_id:
            return self._adapters_by_id[source.id]
        return self._adapters_by_type.get(source.type)

    def _resolve_run_status(
        self,
        source_results: List[SourceIngestionResult],
    ) -> str:
        if not source_results:
            return "failed"
        statuses = {result.status for result in source_results}
        if statuses == {"success"}:
            return "success"
        if "success" in statuses:
            return "partial"
        return "failed"

    def _register_run(self, run: IngestionRunRecord) -> None:
        self._latest_run = run
        self._runs.appendleft(run)
