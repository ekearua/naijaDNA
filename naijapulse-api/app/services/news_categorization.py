from __future__ import annotations

_BUILT_IN_CATEGORY_LABELS = (
    "World News",
    "Business",
    "Technology",
    "Entertainment",
    "Science",
    "Sports",
    "Health",
    "General",
)

_CATEGORY_FALLBACK_MAP = {
    "world": "World News",
    "world news": "World News",
    "politics": "World News",
    "breaking": "World News",
    "breaking news": "World News",
    "international": "World News",
    "business": "Business",
    "technology": "Technology",
    "tech": "Technology",
    "entertainment": "Entertainment",
    "science": "Science",
    "sports": "Sports",
    "sport": "Sports",
    "health": "Health",
    "general": "General",
    "news": "General",
    "top stories": "General",
    "headline stories": "General",
}


def infer_news_category(
    *,
    title: str,
    summary: str | None = None,
    source: str | None = None,
    fallback: str | None = None,
) -> str:
    """Infer a normalized display category for incoming provider items."""
    base = f"{title} {summary or ''} {source or ''}".lower()

    if _contains_any(
        base,
        (
            "health",
            "medical",
            "medicine",
            "hospital",
            "doctor",
            "disease",
            "virus",
            "vaccine",
            "public health",
            "who ",
            "nutrition",
        ),
    ):
        return "Health"

    if _contains_any(
        base,
        (
            "science",
            "research",
            "scientist",
            "space",
            "nasa",
            "laboratory",
            "physics",
            "biology",
            "chemistry",
            "astronomy",
            "climate study",
        ),
    ):
        return "Science"

    if _contains_any(
        base,
        (
            "afcon",
            "fifa",
            "npfl",
            "football",
            "sport",
            "premier league",
            "champions league",
            "goal",
            "match",
            "basketball",
            "tennis",
            "olympic",
        ),
    ):
        return "Sports"

    if _contains_any(
        base,
        (
            "business",
            "finance",
            "economy",
            "naira",
            "cbn",
            "inflation",
            "market",
            "stock",
            "bank",
            "oil price",
            "forex",
        ),
    ):
        return "Business"

    if _contains_any(
        base,
        (
            "technology",
            "tech",
            "startup",
            "software",
            "cyber",
            "ai ",
            "artificial intelligence",
            "mobile app",
            "internet",
            "5g",
            "fintech",
        ),
    ):
        return "Technology"

    if _contains_any(
        base,
        (
            "world",
            "international",
            "politics",
            "election",
            "senate",
            "house of reps",
            "governor",
            "president",
            "apc",
            "pdp",
            "lp ",
            "inec",
            "assembly",
            "minister",
        ),
    ):
        return "Politics"

    if _contains_any(
        base,
        (
            "entertainment",
            "music",
            "movie",
            "actor",
            "actress",
            "nollywood",
            "celebrity",
            "album",
            "streaming",
            "showbiz",
        ),
    ):
        return "Entertainment"

    if _contains_any(
        base,
        (
            "breaking",
            "live update",
            "developing story",
            "just in",
            "urgent",
            "protest",
            "clash",
            "attack",
            "explosion",
        ),
    ):
        return "Breaking News"

    fallback_label = _normalize_fallback_label(fallback)
    if fallback_label is not None:
        return fallback_label
    return "General"


def _contains_any(text: str, keywords: tuple[str, ...]) -> bool:
    for keyword in keywords:
        if keyword in text:
            return True
    return False


def _normalize_fallback_label(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip().lower()
    if not normalized:
        return None
    normalized = normalized.replace("-", " ")
    mapped = _CATEGORY_FALLBACK_MAP.get(normalized)
    if mapped is not None:
        return mapped

    words = [word for word in normalized.split(" ") if word]
    if not words:
        return None
    candidate = " ".join(word[:1].upper() + word[1:] for word in words)
    if candidate in _BUILT_IN_CATEGORY_LABELS:
        return candidate
    return "General"
