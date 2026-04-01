import asyncio
import hashlib
from datetime import datetime
from email.utils import parsedate_to_datetime
from typing import Any, List

import httpx
import feedparser

from app.integrations.news_sources.image_extraction import (
    extract_first_image_from_html_fragments,
    normalize_image_url,
    resolve_page_images,
)
from app.schemas.news import NewsArticle, NewsSourceInfo
from app.services.news_categorization import infer_news_category


class RssNewsSourceAdapter:
    """Fetch and normalize RSS/Atom feeds into canonical `NewsArticle` objects."""

    id = "rss"
    name = "RSS/Atom Adapter"

    async def fetch_latest(
        self,
        source: NewsSourceInfo,
        limit: int = 20,
    ) -> List[NewsArticle]:
        if not source.feed_url:
            return []

        # `feedparser.parse` is blocking; run it in a worker thread.
        parsed = await asyncio.to_thread(feedparser.parse, source.feed_url)
        if parsed.bozo and not parsed.entries:
            # Unreadable feed.
            return []

        feed_title = parsed.feed.get("title", source.name) if parsed.feed else source.name
        articles: List[NewsArticle] = []

        for entry in parsed.entries[:limit]:
            article = self._map_entry_to_article(
                source=source,
                feed_title=feed_title,
                entry=entry,
            )
            if article is not None:
                articles.append(article)

        await self._enrich_missing_images(articles)
        return articles

    def _map_entry_to_article(
        self,
        source: NewsSourceInfo,
        feed_title: str,
        entry: Any,
    ) -> NewsArticle | None:
        title = self._safe_str(entry, "title")
        link = self._safe_str(entry, "link")
        if not title and not link:
            # Ignore malformed entries with no stable identity.
            return None

        published_at = self._parse_published_at(entry)
        source_name = feed_title or source.name
        category = self._infer_category(
            entry=entry,
            title=title,
            source_name=source_name,
        )
        summary = self._safe_str(entry, "summary") or self._safe_str(entry, "description")

        article_id = self._build_article_id(
            source_id=source.id,
            link=link,
            title=title,
            published_at=published_at,
        )
        image_url = self._extract_image(entry, fallback_link=link)

        return NewsArticle(
            id=article_id,
            title=title or "Untitled",
            source=source_name,
            category=category,
            summary=summary,
            url=link or None,
            image_url=image_url or None,
            published_at=published_at,
            fact_checked=False,
        )

    def _parse_published_at(self, entry: Any) -> datetime:
        published_raw = self._safe_str(entry, "published") or self._safe_str(entry, "updated")
        if published_raw:
            try:
                parsed = parsedate_to_datetime(published_raw)
                return parsed.replace(tzinfo=None) if parsed.tzinfo else parsed
            except (ValueError, TypeError):
                # Fall back to current UTC if source timestamps are malformed.
                pass
        return datetime.utcnow()

    def _build_article_id(
        self,
        source_id: str,
        link: str,
        title: str,
        published_at: datetime,
    ) -> str:
        base = "|".join(
            [
                source_id,
                link.strip().lower(),
                title.strip().lower(),
                published_at.strftime("%Y-%m-%d"),
            ]
        )
        return f"{source_id}-{hashlib.sha1(base.encode('utf-8')).hexdigest()[:16]}"

    def _infer_category(
        self,
        *,
        entry: Any,
        title: str,
        source_name: str,
    ) -> str:
        tags = getattr(entry, "tags", None) or []
        fallback: str | None = None
        if tags:
            first = tags[0]
            term = first.get("term") if isinstance(first, dict) else None
            if term:
                fallback = str(term).strip()

        summary = self._safe_str(entry, "summary") or self._safe_str(
            entry,
            "description",
        )
        return infer_news_category(
            title=title,
            summary=summary,
            source=source_name,
            fallback=fallback,
        )

    def _extract_image(self, entry: Any, *, fallback_link: str) -> str:
        entry_image = getattr(entry, "image", None)
        if isinstance(entry_image, dict):
            normalized = normalize_image_url(
                entry_image.get("href") or entry_image.get("url"),
                base_url=fallback_link,
            )
            if normalized:
                return normalized

        media_content = getattr(entry, "media_content", None) or []
        if media_content and isinstance(media_content, list):
            for item in media_content:
                if not isinstance(item, dict):
                    continue
                normalized = normalize_image_url(item.get("url"), base_url=fallback_link)
                if normalized:
                    return normalized

        media_thumbnail = getattr(entry, "media_thumbnail", None) or []
        if media_thumbnail and isinstance(media_thumbnail, list):
            for item in media_thumbnail:
                if not isinstance(item, dict):
                    continue
                normalized = normalize_image_url(item.get("url"), base_url=fallback_link)
                if normalized:
                    return normalized

        links = getattr(entry, "links", None) or []
        for link in links:
            if not isinstance(link, dict):
                continue
            rel = str(link.get("rel", "")).lower()
            link_type = str(link.get("type", "")).lower()
            if rel == "enclosure" or link_type.startswith("image/"):
                normalized = normalize_image_url(
                    link.get("href") or link.get("url"),
                    base_url=fallback_link,
                )
                if normalized:
                    return normalized

        content_blocks = getattr(entry, "content", None) or []
        html_fragments: list[str] = []
        for block in content_blocks:
            if isinstance(block, dict):
                html_fragments.append(str(block.get("value", "")))
        html_fragments.append(self._safe_str(entry, "summary"))
        html_fragments.append(self._safe_str(entry, "description"))

        return extract_first_image_from_html_fragments(
            html_fragments,
            base_url=fallback_link,
        )

    async def _enrich_missing_images(self, articles: List[NewsArticle]) -> None:
        indexed_urls = [
            (index, str(article.url))
            for index, article in enumerate(articles)
            if article.image_url is None and article.url is not None
        ]
        if not indexed_urls:
            return

        timeout = httpx.Timeout(8.0, connect=5.0)
        async with httpx.AsyncClient(
            timeout=timeout,
            follow_redirects=True,
            headers={"User-Agent": "NaijaPulseImageBot/1.0"},
        ) as client:
            resolved = await resolve_page_images(
                client=client,
                indexed_urls=indexed_urls,
                max_candidates=8,
                concurrency=4,
            )

        for index, image_url in resolved.items():
            articles[index] = articles[index].model_copy(update={"image_url": image_url})

    def _safe_str(self, entry: Any, field: str) -> str:
        value = getattr(entry, field, "")
        if value is None:
            return ""
        return str(value).strip()
