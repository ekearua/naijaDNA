import asyncio
from html.parser import HTMLParser
from typing import Iterable, Sequence
from urllib.parse import urljoin

import httpx


class _HtmlImageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.meta_images: list[str] = []
        self.link_images: list[str] = []
        self.first_img_src: str = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        normalized_tag = tag.lower()
        attributes = {
            key.lower(): value.strip()
            for key, value in attrs
            if key and value and value.strip()
        }
        if normalized_tag == "meta":
            property_name = (attributes.get("property") or attributes.get("name") or "").lower()
            itemprop_name = (attributes.get("itemprop") or "").lower()
            if property_name in {
                "og:image",
                "og:image:secure_url",
                "twitter:image",
                "twitter:image:src",
            } or itemprop_name == "image":
                content = attributes.get("content", "")
                if content:
                    self.meta_images.append(content)
            return

        if normalized_tag == "link":
            rel = (attributes.get("rel") or "").lower()
            href = attributes.get("href", "")
            link_type = (attributes.get("type") or "").lower()
            as_value = (attributes.get("as") or "").lower()
            if (
                rel in {"image_src", "apple-touch-icon", "apple-touch-icon-precomposed"}
                or link_type.startswith("image/")
                or as_value == "image"
            ):
                if href:
                    self.link_images.append(href)
            return

        if normalized_tag == "source":
            srcset = attributes.get("srcset", "")
            if srcset:
                candidate = srcset.split(",")[0].strip().split(" ")[0].strip()
                if candidate:
                    self.link_images.append(candidate)
            return

        if normalized_tag == "img" and not self.first_img_src:
            for key in ("src", "data-src", "data-original", "data-lazy-src", "data-srcset"):
                src = attributes.get(key, "")
                if not src:
                    continue
                candidate = src.split(",")[0].strip().split(" ")[0].strip()
                if candidate:
                    self.first_img_src = candidate
                    break


def normalize_image_url(
    candidate: str | None,
    *,
    base_url: str | None = None,
) -> str:
    if not candidate:
        return ""
    value = candidate.strip()
    if not value or value.startswith("data:"):
        return ""
    if value.startswith("//"):
        value = f"https:{value}"
    elif not value.startswith(("http://", "https://")) and base_url:
        value = urljoin(base_url, value)

    if not value.startswith(("http://", "https://")):
        return ""
    return value


def _looks_like_article_image(candidate: str) -> bool:
    lowered = candidate.lower()
    reject_fragments = (
        "logo",
        "icon",
        "favicon",
        "sprite",
        "avatar",
        "placeholder",
        "blank.",
        "pixel.",
        "spacer.",
        "advert",
        "ads/",
        "/ads",
        "doubleclick",
        "googleads",
    )
    return not any(fragment in lowered for fragment in reject_fragments)


def extract_first_image_from_html(
    html_document: str | None,
    *,
    base_url: str | None = None,
) -> str:
    if not html_document:
        return ""

    parser = _HtmlImageParser()
    parser.feed(html_document)
    parser.close()

    for candidate in [*parser.meta_images, *parser.link_images, parser.first_img_src]:
        normalized = normalize_image_url(candidate, base_url=base_url)
        if normalized and _looks_like_article_image(normalized):
            return normalized
    return ""


def extract_first_image_from_html_fragments(
    fragments: Sequence[str],
    *,
    base_url: str | None = None,
) -> str:
    for fragment in fragments:
        image_url = extract_first_image_from_html(fragment, base_url=base_url)
        if image_url:
            return image_url
    return ""


async def fetch_image_from_article_page(
    client: httpx.AsyncClient,
    *,
    article_url: str,
) -> str:
    normalized_article_url = normalize_image_url(article_url)
    if not normalized_article_url:
        return ""

    try:
        response = await client.get(
            normalized_article_url,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/123.0.0.0 Safari/537.36"
                ),
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            },
        )
        response.raise_for_status()
    except Exception:  # noqa: BLE001
        return ""

    content_type = response.headers.get("content-type", "")
    if "html" not in content_type.lower():
        return ""

    # Guard against unusually large pages while keeping enough headroom for meta tags.
    html_document = response.text[:300_000]
    return extract_first_image_from_html(
        html_document,
        base_url=str(response.url),
    )


async def resolve_page_images(
    *,
    client: httpx.AsyncClient,
    indexed_urls: Iterable[tuple[int, str]],
    max_candidates: int = 10,
    concurrency: int = 4,
) -> dict[int, str]:
    candidates = [
        (index, url)
        for index, url in indexed_urls
        if normalize_image_url(url)
    ][: max(0, max_candidates)]
    if not candidates:
        return {}

    semaphore = asyncio.Semaphore(max(1, concurrency))

    async def _resolve(index: int, url: str) -> tuple[int, str]:
        async with semaphore:
            image_url = await fetch_image_from_article_page(client, article_url=url)
            return index, image_url

    results = await asyncio.gather(
        *(_resolve(index, url) for index, url in candidates),
        return_exceptions=True,
    )

    resolved: dict[int, str] = {}
    for result in results:
        if isinstance(result, Exception):
            continue
        index, image_url = result
        if image_url:
            resolved[index] = image_url
    return resolved
