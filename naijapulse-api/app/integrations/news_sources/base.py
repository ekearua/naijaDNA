from typing import List, Protocol

from app.schemas.news import NewsArticle, NewsSourceInfo


class NewsSourceAdapter(Protocol):
    """Contract for pluggable source adapters used by ingestion pipeline."""

    id: str
    name: str

    async def fetch_latest(
        self,
        source: NewsSourceInfo,
        limit: int = 20,
    ) -> List[NewsArticle]:
        ...
