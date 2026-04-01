import json
import logging
from datetime import datetime
from hashlib import sha1
from typing import Any
from urllib.parse import quote

import httpx


logger = logging.getLogger(__name__)


class ResponseCacheService:
    """Small REST cache wrapper for Upstash Redis-backed API response caching."""

    def __init__(
        self,
        *,
        rest_url: str,
        rest_token: str,
        enabled: bool,
        news_top_ttl_seconds: int,
        news_latest_ttl_seconds: int,
        polls_active_ttl_seconds: int,
        categories_ttl_seconds: int,
        tags_ttl_seconds: int,
    ) -> None:
        self._rest_url = rest_url.rstrip("/")
        self._rest_token = rest_token.strip()
        self._enabled = enabled and bool(self._rest_url) and bool(self._rest_token)
        self._namespace_versions: dict[str, int] = {}
        self.news_top_ttl_seconds = news_top_ttl_seconds
        self.news_latest_ttl_seconds = news_latest_ttl_seconds
        self.polls_active_ttl_seconds = polls_active_ttl_seconds
        self.categories_ttl_seconds = categories_ttl_seconds
        self.tags_ttl_seconds = tags_ttl_seconds
        self._client: httpx.AsyncClient | None = None
        self._read_count = 0
        self._hit_count = 0
        self._miss_count = 0
        self._write_count = 0
        self._error_count = 0
        self._last_error_at: datetime | None = None
        self._last_error_message: str | None = None

    @property
    def enabled(self) -> bool:
        return self._enabled

    async def startup(self) -> None:
        if not self._enabled:
            return
        self._client = httpx.AsyncClient(
            timeout=10.0,
            headers={"Authorization": f"Bearer {self._rest_token}"},
        )

    async def shutdown(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def get_json(self, *, namespace: str, identifier: str) -> Any | None:
        if not self._enabled:
            return None
        client = self._client
        if client is None:
            return None

        key = self._cache_key(namespace=namespace, identifier=identifier)
        self._read_count += 1
        try:
            response = await client.get(f"{self._rest_url}/get/{quote(key, safe='')}")
            response.raise_for_status()
            payload = response.json()
            raw = payload.get("result")
            if raw is None:
                self._miss_count += 1
                return None
            self._hit_count += 1
            if isinstance(raw, str):
                return json.loads(raw)
            return raw
        except Exception as exc:  # noqa: BLE001
            self._register_error(exc)
            logger.warning("Response cache read failed for %s: %s", key, exc)
            return None

    async def set_json(
        self,
        *,
        namespace: str,
        identifier: str,
        value: Any,
        ttl_seconds: int,
    ) -> None:
        if not self._enabled:
            return
        client = self._client
        if client is None:
            return

        key = self._cache_key(namespace=namespace, identifier=identifier)
        serialized = json.dumps(value, separators=(",", ":"), ensure_ascii=True)
        try:
            response = await client.post(
                self._rest_url,
                json=["SET", key, serialized, "EX", str(ttl_seconds)],
            )
            response.raise_for_status()
            self._write_count += 1
        except Exception as exc:  # noqa: BLE001
            self._register_error(exc)
            logger.warning("Response cache write failed for %s: %s", key, exc)

    async def invalidate_namespace(self, namespace: str) -> None:
        current = self._namespace_versions.get(namespace, 1)
        self._namespace_versions[namespace] = current + 1

    def _cache_key(self, *, namespace: str, identifier: str) -> str:
        version = self._namespace_versions.get(namespace, 1)
        digest = sha1(identifier.encode("utf-8")).hexdigest()
        return f"naijapulse:{namespace}:v{version}:{digest}"

    def diagnostics(self) -> dict[str, Any]:
        return {
            "enabled": self._enabled,
            "configured": bool(self._rest_url) and bool(self._rest_token),
            "client_ready": self._client is not None,
            "news_top_ttl_seconds": self.news_top_ttl_seconds,
            "news_latest_ttl_seconds": self.news_latest_ttl_seconds,
            "polls_active_ttl_seconds": self.polls_active_ttl_seconds,
            "categories_ttl_seconds": self.categories_ttl_seconds,
            "tags_ttl_seconds": self.tags_ttl_seconds,
            "read_count": self._read_count,
            "hit_count": self._hit_count,
            "miss_count": self._miss_count,
            "write_count": self._write_count,
            "error_count": self._error_count,
            "last_error_at": self._last_error_at,
            "last_error_message": self._last_error_message,
            "namespaces": [
                {"namespace": namespace, "version": version}
                for namespace, version in sorted(self._namespace_versions.items())
            ],
        }

    def _register_error(self, exc: Exception) -> None:
        self._error_count += 1
        self._last_error_at = datetime.utcnow()
        self._last_error_message = str(exc)
