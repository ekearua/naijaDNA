import json
import logging
from dataclasses import dataclass, field
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, messaging


logger = logging.getLogger(__name__)


@dataclass(slots=True)
class PushDispatchResult:
    success_count: int = 0
    failure_count: int = 0
    invalid_tokens: list[str] = field(default_factory=list)


class PushNotificationService:
    """Firebase Cloud Messaging sender backed by the Admin SDK."""

    def __init__(
        self,
        *,
        service_account_json: str,
        app_name: str = "naijapulse-fcm",
    ) -> None:
        self._app = None
        self._enabled = False
        self._app_name = app_name

        raw_value = (service_account_json or "").strip()
        if not raw_value:
            logger.info("FCM disabled: FIREBASE_SERVICE_ACCOUNT_JSON is not configured.")
            return

        try:
            certificate_source = self._resolve_certificate_source(raw_value)
            self._app = firebase_admin.initialize_app(
                credentials.Certificate(certificate_source),
                name=self._app_name,
            )
            self._enabled = True
            logger.info("FCM enabled for Firebase push delivery.")
        except ValueError:
            try:
                self._app = firebase_admin.get_app(self._app_name)
                self._enabled = True
            except ValueError:
                logger.exception("FCM setup failed. Push delivery will be disabled.")
                self._enabled = False
                self._app = None
        except Exception:  # noqa: BLE001
            logger.exception("FCM setup failed. Push delivery will be disabled.")
            self._enabled = False
            self._app = None

    @property
    def enabled(self) -> bool:
        return self._enabled and self._app is not None

    def send_notification(
        self,
        *,
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, str],
    ) -> PushDispatchResult:
        if not self.enabled:
            return PushDispatchResult()

        normalized_tokens = [token.strip() for token in tokens if token.strip()]
        if not normalized_tokens:
            return PushDispatchResult()

        message = messaging.MulticastMessage(
            tokens=normalized_tokens,
            notification=messaging.Notification(title=title, body=body),
            data=data,
            android=messaging.AndroidConfig(priority="high"),
        )

        try:
            response = messaging.send_each_for_multicast(message, app=self._app)
        except Exception:  # noqa: BLE001
            logger.exception("FCM send failed for %s token(s).", len(normalized_tokens))
            return PushDispatchResult(
                success_count=0,
                failure_count=len(normalized_tokens),
            )

        invalid_tokens: list[str] = []
        for token, send_response in zip(normalized_tokens, response.responses):
            if send_response.success:
                continue

            error_code = str(getattr(send_response.error, "code", "") or "").lower()
            if any(
                marker in error_code
                for marker in (
                    "registration-token-not-registered",
                    "invalid-registration-token",
                    "invalid-argument",
                    "unregistered",
                )
            ):
                invalid_tokens.append(token)

        return PushDispatchResult(
            success_count=response.success_count,
            failure_count=response.failure_count,
            invalid_tokens=invalid_tokens,
        )

    def _resolve_certificate_source(self, raw_value: str) -> dict[str, str] | str:
        if raw_value.startswith("{"):
            payload = json.loads(raw_value)
            if not isinstance(payload, dict):
                raise ValueError("Firebase service account JSON must decode to an object.")
            return payload

        path = Path(raw_value)
        if path.exists():
            return str(path)

        raise ValueError(
            "FIREBASE_SERVICE_ACCOUNT_JSON must be a JSON object string or a file path."
        )
