import re
from dataclasses import dataclass
from html import unescape

import httpx

from app.core.text import plain_text_excerpt
from app.schemas.news import NewsArticle, NewsReadableTextResponse


@dataclass(slots=True)
class _ReadableContent:
    text: str
    method: str
    used_fallback: bool


class ArticleReadabilityService:
    """Fetch publisher HTML and derive a readable text body for TTS/read-aloud."""

    def __init__(self) -> None:
        self._client: httpx.AsyncClient | None = None

    async def startup(self) -> None:
        if self._client is not None:
            return
        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(12.0, connect=5.0),
            follow_redirects=True,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (compatible; NaijaPulseReadableText/1.0; "
                    "+https://naijapulse.local)"
                ),
                "Accept": "text/html,application/xhtml+xml",
            },
        )

    async def shutdown(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def get_readable_text(self, article: NewsArticle) -> NewsReadableTextResponse:
        content = await self._extract_content(article)
        word_count = len(re.findall(r"\b\w+\b", content.text))
        return NewsReadableTextResponse(
            article_id=article.id,
            title=article.title,
            source=article.source,
            article_url=article.url,
            text=content.text,
            word_count=word_count,
            extraction_method=content.method,
            used_fallback=content.used_fallback,
        )

    async def _extract_content(self, article: NewsArticle) -> _ReadableContent:
        source_url = str(article.url) if article.url is not None else ""
        if not source_url:
            return self._fallback_content(article, method="summary_only")

        if self._client is None:
            await self.startup()

        try:
            assert self._client is not None
            response = await self._client.get(source_url)
            response.raise_for_status()
        except httpx.HTTPError:
            return self._fallback_content(article, method="publisher_fetch_failed")

        readable_text = self._extract_from_html(response.text)
        if readable_text is None or len(readable_text.split()) < 80:
            return self._fallback_content(
                article,
                method="publisher_content_too_thin",
                extra_text=readable_text,
            )

        combined_text = self._combine_parts(
            title=article.title,
            summary=article.summary,
            review_notes=article.review_notes,
            body=readable_text,
        )
        return _ReadableContent(
            text=combined_text,
            method="publisher_html",
            used_fallback=False,
        )

    def _fallback_content(
        self,
        article: NewsArticle,
        *,
        method: str,
        extra_text: str | None = None,
    ) -> _ReadableContent:
        text = self._combine_parts(
            title=article.title,
            summary=article.summary,
            review_notes=article.review_notes,
            body=extra_text,
        )
        if not text.strip():
            text = article.title.strip()
        return _ReadableContent(text=text, method=method, used_fallback=True)

    def _combine_parts(
        self,
        *,
        title: str | None,
        summary: str | None,
        review_notes: str | None,
        body: str | None,
    ) -> str:
        parts: list[str] = []
        for raw_part in [title, summary, review_notes, body]:
            cleaned = plain_text_excerpt(raw_part) or ""
            if not cleaned:
                continue
            if cleaned in parts:
                continue
            if any(cleaned in existing for existing in parts):
                continue
            parts.append(cleaned)
        return "\n\n".join(parts).strip()

    def _extract_from_html(self, html: str) -> str | None:
        candidate = self._pick_primary_block(html) or self._extract_body(html)
        if not candidate:
            return None

        candidate = self._strip_unwanted_blocks(candidate)
        paragraphs = self._extract_paragraphs(candidate)
        if not paragraphs:
            cleaned = self._html_to_text(candidate)
            return cleaned or None

        deduped: list[str] = []
        seen: set[str] = set()
        for paragraph in paragraphs:
            normalized = paragraph.strip()
            key = normalized.lower()
            if len(normalized.split()) < 4 or key in seen:
                continue
            seen.add(key)
            deduped.append(normalized)

        if not deduped:
            return None

        return "\n\n".join(deduped[:16]).strip()

    def _pick_primary_block(self, html: str) -> str | None:
        patterns = [
            r"<article\b[^>]*>(?P<content>.*?)</article>",
            r"<main\b[^>]*>(?P<content>.*?)</main>",
            r'<div\b[^>]+(?:id|class)="[^"]*(?:article|story|content|post-body|entry-content)[^"]*"[^>]*>(?P<content>.*?)</div>',
            r"<section\b[^>]*>(?P<content>.*?)</section>",
        ]
        for pattern in patterns:
            match = re.search(pattern, html, flags=re.IGNORECASE | re.DOTALL)
            if match:
                content = match.group("content")
                if content and len(content) > 200:
                    return content
        return None

    def _extract_body(self, html: str) -> str | None:
        match = re.search(
            r"<body\b[^>]*>(?P<content>.*?)</body>",
            html,
            flags=re.IGNORECASE | re.DOTALL,
        )
        if not match:
            return None
        return match.group("content")

    def _strip_unwanted_blocks(self, html: str) -> str:
        cleaned = re.sub(
            r"<(script|style|noscript|svg|iframe|canvas)[^>]*>.*?</\1>",
            " ",
            html,
            flags=re.IGNORECASE | re.DOTALL,
        )
        cleaned = re.sub(
            r"<(header|footer|nav|aside|form|button|figure|figcaption)[^>]*>.*?</\1>",
            " ",
            cleaned,
            flags=re.IGNORECASE | re.DOTALL,
        )
        return cleaned

    def _extract_paragraphs(self, html: str) -> list[str]:
        matches = re.findall(
            r"<p\b[^>]*>(.*?)</p>",
            html,
            flags=re.IGNORECASE | re.DOTALL,
        )
        return [self._html_to_text(item) for item in matches if self._html_to_text(item)]

    def _html_to_text(self, value: str) -> str:
        text = re.sub(r"<br\s*/?>", "\n", value, flags=re.IGNORECASE)
        text = re.sub(r"</(p|div|section|article|li|h[1-6])>", "\n", text, flags=re.IGNORECASE)
        text = re.sub(r"<[^>]+>", " ", text)
        text = unescape(text)
        text = re.sub(r"\s+", " ", text)
        return text.strip()
