import asyncio
import hashlib
import math
from datetime import datetime, timezone
from typing import Any, List

import httpx
from pydantic import ValidationError

from app.integrations.news_sources.image_extraction import resolve_page_images
from app.schemas.news import NewsArticle, NewsSourceInfo
from app.services.news_categorization import infer_news_category


class GNewsNewsSourceAdapter:
    """Fetch and normalize articles from GNews top-headlines."""

    id = "gnews"
    name = "GNews Adapter"

    def __init__(
        self,
        api_key: str,
        *,
        max_results_per_request: int = 10,
        request_spacing_seconds: float = 1.1,
    ) -> None:
        self._api_key = api_key.strip()
        self._max_results_per_request = max(1, min(max_results_per_request, 10))
        self._request_spacing_seconds = max(0.0, request_spacing_seconds)

    async def fetch_latest(
        self,
        source: NewsSourceInfo,
        limit: int = 20,
    ) -> List[NewsArticle]:
        if not self._api_key:
            return []

        base_url = (source.api_base_url or "https://gnews.io/api/v4").rstrip("/")
        articles: List[NewsArticle] = []
        seen_fingerprints: set[str] = set()
        categories = self._top_headline_categories()
        page_size = max(
            1,
            min(
                self._max_results_per_request,
                math.ceil(max(limit, 1) / max(len(categories), 1)),
            ),
        )
        async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
            for index, category in enumerate(categories):
                if index > 0:
                    await self._maybe_wait_between_requests()
                payload = await self._fetch_top_headlines(
                    client=client,
                    base_url=base_url,
                    category=category,
                    page_size=page_size,
                )
                self._append_articles(
                    target=articles,
                    source=source,
                    raw_items=payload.get("articles", []),
                    seen_fingerprints=seen_fingerprints,
                    limit=limit,
                    category=category,
                )
                if len(articles) >= limit:
                    break

            indexed_urls = [
                (index, str(article.url))
                for index, article in enumerate(articles)
                if article.image_url is None and article.url is not None
            ]
            resolved_images = await resolve_page_images(
                client=client,
                indexed_urls=indexed_urls,
                max_candidates=6,
                concurrency=3,
            )
            for index, image_url in resolved_images.items():
                articles[index] = articles[index].model_copy(update={"image_url": image_url})

        return articles[:limit]

    async def _maybe_wait_between_requests(self) -> None:
        if self._request_spacing_seconds <= 0:
            return
        await asyncio.sleep(self._request_spacing_seconds)

    async def _fetch_top_headlines(
        self,
        *,
        client: httpx.AsyncClient,
        base_url: str,
        category: str,
        page_size: int,
    ) -> dict:
        params = {
            "token": self._api_key,
            "country": "ng",
            "lang": "en",
            "category": category,
            "max": page_size,
        }
        response = await client.get(f"{base_url}/top-headlines", params=params)
        response.raise_for_status()
        return response.json()

    def _append_articles(
        self,
        *,
        target: list[NewsArticle],
        source: NewsSourceInfo,
        raw_items: list[Any],
        seen_fingerprints: set[str],
        limit: int,
        category: str,
    ) -> None:
        for item in raw_items:
            if len(target) >= limit:
                break
            article = self._map_item_to_article(
                source=source,
                item=item,
                category=category,
            )
            if article is None:
                continue
            fingerprint = self._dedupe_fingerprint(article)
            if fingerprint in seen_fingerprints:
                continue
            seen_fingerprints.add(fingerprint)
            target.append(article)

    def _top_headline_categories(self) -> list[str]:
        return [
            "general",
            "world",
            "business",
            "technology",
            "entertainment",
            "sports",
            "science",
            "health",
        ]

    def _category_fallback_label(self, category: str) -> str:
        normalized = category.strip().lower()
        return {
            "general": "General",
            "world": "World News",
            "business": "Business",
            "technology": "Technology",
            "entertainment": "Entertainment",
            "sports": "Sports",
            "science": "Science",
            "health": "Health",
        }.get(normalized, "General")

    def _dedupe_fingerprint(self, article: NewsArticle) -> str:
        return "|".join(
            [
                (str(article.url) if article.url else "").strip().lower(),
                article.title.strip().lower(),
                article.source.strip().lower(),
            ]
        )

    def _map_item_to_article(
        self,
        *,
        source: NewsSourceInfo,
        item: Any,
        category: str,
    ) -> NewsArticle | None:
        if not isinstance(item, dict):
            return None

        title = self._safe_str(item.get("title")) or "Untitled"
        article_url = self._safe_url(item.get("url"))
        if not title and not article_url:
            return None

        source_info = item.get("source") if isinstance(item.get("source"), dict) else {}
        source_name = self._safe_str(source_info.get("name")) or source.name
        published_at = self._parse_published_at(self._safe_str(item.get("publishedAt")))
        summary = self._safe_str(item.get("description")) or self._safe_str(item.get("content"))
        inferred_category = infer_news_category(
            title=title,
            summary=summary,
            source=source_name,
            fallback=self._category_fallback_label(category),
        )
        image_url = self._safe_url(item.get("image"))
        article_id = self._build_article_id(
            source_id=source.id,
            article_url=article_url,
            title=title,
            published_at=published_at,
        )

        try:
            return NewsArticle(
                id=article_id,
                title=title,
                source=source_name,
                category=inferred_category,
                tags=[inferred_category],
                summary=summary or None,
                url=article_url or None,
                image_url=image_url or None,
                published_at=published_at,
                fact_checked=False,
            )
        except ValidationError:
            # Skip malformed provider rows instead of failing the whole run.
            return None

    def _parse_published_at(self, value: str) -> datetime:
        if value:
            try:
                parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
                if parsed.tzinfo:
                    return parsed.astimezone(timezone.utc).replace(tzinfo=None)
                return parsed
            except ValueError:
                pass
        return datetime.utcnow()

    def _build_article_id(
        self,
        *,
        source_id: str,
        article_url: str,
        title: str,
        published_at: datetime,
    ) -> str:
        base = "|".join(
            [
                source_id,
                article_url.strip().lower(),
                title.strip().lower(),
                published_at.strftime("%Y-%m-%d"),
            ]
        )
        return f"{source_id}-{hashlib.sha1(base.encode('utf-8')).hexdigest()[:16]}"

    def _safe_str(self, value: Any) -> str:
        if value is None:
            return ""
        return str(value).strip()

    def _safe_url(self, value: Any) -> str:
        candidate = self._safe_str(value)
        if candidate.startswith(("http://", "https://")):
            return candidate
        return ""
