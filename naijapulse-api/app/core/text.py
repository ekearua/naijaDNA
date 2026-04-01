import re
from html import unescape


def plain_text_excerpt(value: str | None) -> str | None:
    normalized = (value or "").strip()
    if not normalized:
        return None

    without_tags = re.sub(r"<[^>]*>", " ", normalized)
    decoded = unescape(without_tags)
    collapsed = re.sub(r"\s+", " ", decoded).strip()
    return collapsed or None
