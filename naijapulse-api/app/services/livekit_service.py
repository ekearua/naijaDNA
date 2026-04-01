from datetime import timedelta

import livekit.api as api

from app.schemas.streams import StreamSession


class LiveKitConfigurationError(Exception):
    pass


class LiveKitIdentityError(Exception):
    pass


class LiveKitStateError(Exception):
    pass


class LiveKitService:
    """Mint LiveKit participant tokens from the backend so secrets stay server-side."""

    def __init__(
        self,
        *,
        url: str,
        api_key: str,
        api_secret: str,
        token_ttl_seconds: int = 3600,
    ) -> None:
        self._url = url.strip()
        self._api_key = api_key.strip()
        self._api_secret = api_secret.strip()
        self._token_ttl_seconds = token_ttl_seconds

    @property
    def enabled(self) -> bool:
        return all((self._url, self._api_key, self._api_secret))

    def build_connection(
        self,
        *,
        stream: StreamSession,
        user_id: str | None,
        viewer_id: str | None,
    ) -> dict[str, object]:
        if not self.enabled:
            raise LiveKitConfigurationError(
                "LiveKit Cloud is not configured on this server yet."
            )
        if stream.status != "live":
            raise LiveKitStateError("Only live streams can issue LiveKit connection tokens.")

        normalized_user_id = self._normalize_identity(user_id)
        normalized_viewer_id = self._normalize_identity(viewer_id)
        participant_key = normalized_user_id or normalized_viewer_id
        if participant_key is None:
            raise LiveKitIdentityError(
                "A signed-in user or viewer_id is required to join a stream."
            )

        is_host = normalized_user_id is not None and normalized_user_id == stream.host_user_id
        participant_identity = (
            f"host:{normalized_user_id}"
            if is_host
            else f"viewer:{participant_key}"
        )
        participant_name = self._participant_name(stream, normalized_user_id, is_host)
        room_name = self._room_name(stream.id)

        grants = api.VideoGrants(
            room_join=True,
            room=room_name,
            can_publish=is_host,
            can_publish_data=is_host,
            can_subscribe=True,
        )
        token = (
            api.AccessToken(self._api_key, self._api_secret)
            .with_identity(participant_identity)
            .with_name(participant_name)
            .with_ttl(timedelta(seconds=self._token_ttl_seconds))
            .with_grants(grants)
            .to_jwt()
        )

        return {
            "ws_url": self._url,
            "token": token,
            "room_name": room_name,
            "participant_identity": participant_identity,
            "participant_name": participant_name,
            "can_publish": is_host,
            "can_subscribe": True,
        }

    def _normalize_identity(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        return normalized[:128]

    def _participant_name(
        self,
        stream: StreamSession,
        user_id: str | None,
        is_host: bool,
    ) -> str:
        if is_host and stream.host_name:
            return stream.host_name.strip()
        if user_id:
            return user_id[:48]
        return "Guest Viewer"

    def _room_name(self, stream_id: str) -> str:
        return f"naijapulse-{stream_id.strip()}"
