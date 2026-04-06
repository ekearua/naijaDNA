import base64
import hashlib
import hmac
import logging
import secrets
from datetime import datetime, timedelta
from urllib.parse import parse_qsl, quote, urlencode, urlparse, urlunparse
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.db.models import (
    AdminAccessRequestRecord,
    UserAccessRequestRecord,
    UserPreferenceRecord,
    UserRecord,
)
from app.schemas.auth import (
    AdminAccessRequestCreate,
    AdminAccessRequestResponse,
    AuthResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
)
from app.schemas.users import (
    CreateUserRequest,
    UserAccessRequestCreate,
    UserAccessRequestItem,
    UserAccessRequestsResponse,
    UpdateUserPreferencesRequest,
    UpdateUserRequest,
    User,
    UserEntitlements,
    UserPreferences,
)
from app.services.email_service import EmailService


logger = logging.getLogger(__name__)


class UserNotFoundError(Exception):
    pass


class UserAlreadyExistsError(Exception):
    pass


class InvalidUserPayloadError(Exception):
    pass


class InvalidCredentialsError(Exception):
    pass


class PasswordResetTokenError(Exception):
    pass


class AccessRequestAlreadyPendingError(Exception):
    pass


class UsersService:
    """User profile service for account creation and profile updates."""

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        *,
        token_secret: str,
        access_token_ttl_seconds: int,
        email_service: EmailService,
        email_web_base_url: str,
        email_admin_web_base_url: str,
    ) -> None:
        self._session_factory = session_factory
        self._token_secret = token_secret
        self._access_token_ttl_seconds = access_token_ttl_seconds
        self._password_reset_ttl_seconds = 60 * 30
        self._email_service = email_service
        self._email_web_base_url = email_web_base_url.strip()
        self._email_admin_web_base_url = email_admin_web_base_url.strip()

    async def create_user(self, payload: CreateUserRequest) -> User:
        user_id = self._normalize_user_id(payload.id)
        email = self._normalize_email(payload.email)
        display_name = self._normalize_text(payload.display_name, max_length=120)
        avatar_url = self._normalize_text(
            str(payload.avatar_url) if payload.avatar_url else None,
            max_length=4096,
        )

        async with self._session_factory() as session:
            await self._ensure_unique_user(session, user_id=user_id, email=email)

            now = datetime.utcnow()
            user = UserRecord(
                id=user_id,
                email=email,
                password_hash=None,
                display_name=display_name,
                avatar_url=avatar_url,
                is_active=True,
                role="user",
                subscription_tier="free",
                stream_access_granted=payload.stream_access_granted,
                stream_hosting_granted=payload.stream_hosting_granted,
                contribution_access_granted=payload.contribution_access_granted,
                billing_provider=None,
                provider_customer_id=None,
                provider_subscription_id=None,
                subscription_status="inactive",
                current_period_start=None,
                current_period_end=None,
                cancel_at_period_end=False,
                last_payment_at=None,
                subscription_started_at=None,
                subscription_expires_at=None,
                created_at=now,
                updated_at=now,
            )
            session.add(user)
            # Create one preferences row per user as the defaults source.
            session.add(
                UserPreferenceRecord(
                    user_id=user_id,
                    breaking_news_alerts=True,
                    live_stream_alerts=True,
                    comment_replies=True,
                    theme="system",
                    text_size="small",
                    created_at=now,
                    updated_at=now,
                )
            )
            await session.commit()
            return self._to_schema(user)

    async def register_user(self, payload: RegisterRequest) -> AuthResponse:
        email = self._normalize_email(payload.email)
        if email is None:
            raise InvalidUserPayloadError("Email is required.")
        password = self._validate_password(payload.password)
        display_name = self._normalize_text(payload.display_name, max_length=120)
        if display_name is None:
            display_name = email.split("@", 1)[0]

        user_id = self._normalize_user_id(None)
        now = datetime.utcnow()

        async with self._session_factory() as session:
            await self._ensure_unique_user(session, user_id=user_id, email=email)

            user = UserRecord(
                id=user_id,
                email=email,
                password_hash=self._hash_password(password),
                display_name=display_name,
                avatar_url=None,
                is_active=True,
                role="user",
                subscription_tier="free",
                stream_access_granted=False,
                stream_hosting_granted=False,
                contribution_access_granted=False,
                billing_provider=None,
                provider_customer_id=None,
                provider_subscription_id=None,
                subscription_status="inactive",
                current_period_start=None,
                current_period_end=None,
                cancel_at_period_end=False,
                last_payment_at=None,
                subscription_started_at=None,
                subscription_expires_at=None,
                created_at=now,
                updated_at=now,
            )
            session.add(user)
            session.add(
                UserPreferenceRecord(
                    user_id=user_id,
                    breaking_news_alerts=True,
                    live_stream_alerts=True,
                    comment_replies=True,
                    theme="system",
                    text_size="small",
                    created_at=now,
                    updated_at=now,
                )
            )
            await session.commit()

            return AuthResponse(
                access_token=self._issue_access_token(user_id=user.id),
                expires_in_seconds=self._access_token_ttl_seconds,
                user=self._to_schema(user),
            )

    async def login_user(self, payload: LoginRequest) -> AuthResponse:
        email = self._normalize_email(payload.email)
        if email is None:
            raise InvalidUserPayloadError("Email is required.")
        password = self._validate_password(payload.password)

        async with self._session_factory() as session:
            result = await session.execute(
                select(UserRecord).where(func.lower(UserRecord.email) == email.lower())
            )
            user = result.scalar_one_or_none()
            if user is None:
                raise InvalidCredentialsError("Invalid email or password.")
            if not user.is_active:
                raise InvalidCredentialsError("This account is disabled.")
            if not user.password_hash:
                raise InvalidCredentialsError(
                    "Password login is not configured for this account."
                )
            if not self._verify_password(password, user.password_hash):
                raise InvalidCredentialsError("Invalid email or password.")

            user.updated_at = datetime.utcnow()
            await session.commit()

            return AuthResponse(
                access_token=self._issue_access_token(user_id=user.id),
                expires_in_seconds=self._access_token_ttl_seconds,
                user=self._to_schema(user),
            )

    async def request_password_reset(
        self,
        payload: ForgotPasswordRequest,
    ) -> ForgotPasswordResponse:
        email = self._normalize_email(payload.email)
        if email is None:
            raise InvalidUserPayloadError("Email is required.")

        reset_path = self._normalize_reset_path(payload.reset_path)
        message = (
            "If an account exists for this email, a reset link has been generated."
        )

        async with self._session_factory() as session:
            result = await session.execute(
                select(UserRecord).where(func.lower(UserRecord.email) == email.lower())
            )
            user = result.scalar_one_or_none()
            if (
                user is None
                or not user.is_active
                or not user.password_hash
            ):
                return ForgotPasswordResponse(
                    message=message,
                    expires_in_seconds=self._password_reset_ttl_seconds,
                )

            token = self._issue_password_reset_token(
                user_id=user.id,
                password_hash=user.password_hash,
            )
            reset_url = self._build_password_reset_url(
                reset_path=reset_path,
                token=token,
            )
            if self._email_service.enabled and user.email:
                expires_minutes = max(1, self._password_reset_ttl_seconds // 60)
                sent = await self._email_service.send_password_reset_email(
                    to_email=user.email,
                    recipient_name=user.display_name,
                    reset_url=reset_url,
                    expires_minutes=expires_minutes,
                )
                if sent:
                    return ForgotPasswordResponse(
                        message=message,
                        expires_in_seconds=self._password_reset_ttl_seconds,
                    )
                logger.warning(
                    "Password reset email was not delivered for user_id=%s; returning development reset URL fallback.",
                    user.id,
                )
            return ForgotPasswordResponse(
                message=message,
                expires_in_seconds=self._password_reset_ttl_seconds,
                reset_token=token,
                reset_url=reset_url,
            )

    async def reset_password(
        self,
        payload: ResetPasswordRequest,
    ) -> ResetPasswordResponse:
        password = self._validate_password(payload.password)
        token_data = self._decode_password_reset_token(payload.token)

        async with self._session_factory() as session:
            user = await self._load_user_or_raise(session, token_data["user_id"])
            if not user.is_active:
                raise PasswordResetTokenError("This account is disabled.")
            password_hash = user.password_hash or ""
            if self._password_hash_fingerprint(password_hash) != token_data["fingerprint"]:
                raise PasswordResetTokenError(
                    "This reset link is no longer valid. Request a new one."
                )

            user.password_hash = self._hash_password(password)
            user.updated_at = datetime.utcnow()
            email = (user.email or "").strip()
            display_name = user.display_name
            await session.commit()

        if email and self._email_service.enabled:
            await self._email_service.send_password_changed_confirmation(
                to_email=email,
                recipient_name=display_name,
            )

        return ResetPasswordResponse(message="Password updated successfully.")

    async def create_admin_access_request(
        self,
        payload: AdminAccessRequestCreate,
    ) -> AdminAccessRequestResponse:
        full_name = self._normalize_text(payload.full_name, max_length=120)
        work_email = self._normalize_email(payload.work_email)
        requested_role = self._normalize_text(payload.requested_role, max_length=120)
        bureau = self._normalize_text(payload.bureau, max_length=120)
        reason = self._normalize_text(payload.reason, max_length=2000)

        if full_name is None:
            raise InvalidUserPayloadError("Full name is required.")
        if work_email is None:
            raise InvalidUserPayloadError("Work email is required.")
        if requested_role is None:
            raise InvalidUserPayloadError("Role or team is required.")
        if reason is None or len(reason) < 8:
            raise InvalidUserPayloadError(
                "Provide a short reason for access using at least 8 characters."
            )

        async with self._session_factory() as session:
            existing_user_result = await session.execute(
                select(UserRecord).where(func.lower(UserRecord.email) == work_email.lower())
            )
            existing_user = existing_user_result.scalar_one_or_none()
            if (
                existing_user is not None
                and existing_user.is_active
                and existing_user.role in {"editor", "admin"}
            ):
                raise InvalidUserPayloadError(
                    "This email already has editorial dashboard access. Log in instead."
                )

            pending_request_result = await session.execute(
                select(AdminAccessRequestRecord)
                .where(func.lower(AdminAccessRequestRecord.work_email) == work_email.lower())
                .where(AdminAccessRequestRecord.status == "pending")
                .order_by(AdminAccessRequestRecord.created_at.desc())
            )
            pending_request = pending_request_result.scalars().first()
            if pending_request is not None:
                return AdminAccessRequestResponse(
                    message=(
                        "A newsroom access request for this email is already pending review."
                    ),
                    request_id=pending_request.id,
                    status=pending_request.status,
                )

            now = datetime.utcnow()
            access_request = AdminAccessRequestRecord(
                id=f"access-{uuid4().hex[:12]}",
                full_name=full_name,
                work_email=work_email,
                requested_role=requested_role,
                bureau=bureau,
                reason=reason,
                status="pending",
                created_at=now,
                updated_at=now,
            )
            session.add(access_request)
            request_id = access_request.id
            request_status = access_request.status
            await session.commit()
            if self._email_service.enabled and work_email:
                await self._email_service.send_access_request_received_email(
                    to_email=work_email,
                    recipient_name=full_name,
                    request_label=f"newsroom access ({requested_role})",
                    request_id=request_id,
                )

        return AdminAccessRequestResponse(
            message=(
                "Your request has been sent to the platform administrator."
            ),
            request_id=request_id,
            status=request_status,
        )

    async def get_user(self, user_id: str) -> User:
        normalized_user_id = self._normalize_user_id(user_id, generate=False)
        async with self._session_factory() as session:
            result = await session.execute(
                select(UserRecord).where(UserRecord.id == normalized_user_id)
            )
            user = result.scalar_one_or_none()
            if user is None:
                raise UserNotFoundError(f"User '{normalized_user_id}' does not exist.")
            return self._to_schema(user)

    async def update_user(self, user_id: str, payload: UpdateUserRequest) -> User:
        normalized_user_id = self._normalize_user_id(user_id, generate=False)
        async with self._session_factory() as session:
            result = await session.execute(
                select(UserRecord).where(UserRecord.id == normalized_user_id)
            )
            user = result.scalar_one_or_none()
            if user is None:
                raise UserNotFoundError(f"User '{normalized_user_id}' does not exist.")

            update_data = payload.model_dump(exclude_unset=True)
            if not update_data:
                return self._to_schema(user)

            if "email" in update_data:
                email = self._normalize_email(update_data.get("email"))
                if email != user.email:
                    await self._ensure_unique_email(
                        session,
                        email=email,
                        exclude_user_id=normalized_user_id,
                    )
                user.email = email

            if "display_name" in update_data:
                user.display_name = self._normalize_text(
                    update_data.get("display_name"),
                    max_length=120,
                )

            if "avatar_url" in update_data:
                user.avatar_url = self._normalize_text(
                    str(update_data.get("avatar_url")) if update_data.get("avatar_url") else None,
                    max_length=4096,
                )

            if "is_active" in update_data and update_data["is_active"] is not None:
                user.is_active = bool(update_data["is_active"])
            if "stream_access_granted" in update_data and update_data["stream_access_granted"] is not None:
                user.stream_access_granted = bool(update_data["stream_access_granted"])
            if "stream_hosting_granted" in update_data and update_data["stream_hosting_granted"] is not None:
                user.stream_hosting_granted = bool(update_data["stream_hosting_granted"])
            if "contribution_access_granted" in update_data and update_data["contribution_access_granted"] is not None:
                user.contribution_access_granted = bool(update_data["contribution_access_granted"])

            user.updated_at = datetime.utcnow()
            await session.commit()
            return self._to_schema(user)

    async def create_user_access_request(
        self,
        *,
        user_id: str,
        payload: UserAccessRequestCreate,
    ) -> UserAccessRequestItem:
        normalized_user_id = self._normalize_user_id(user_id, generate=False)
        reason = self._normalize_text(payload.reason, max_length=2000)
        access_type = payload.access_type
        if reason is None or len(reason) < 8:
            raise InvalidUserPayloadError(
                "Please provide a short reason using at least 8 characters."
            )

        async with self._session_factory() as session:
            user = await self._load_user_or_raise(session, normalized_user_id)
            if not user.is_active:
                raise InvalidUserPayloadError("This account is disabled.")
            if self._user_already_has_access(user, access_type):
                raise InvalidUserPayloadError("This account already has that access.")

            existing_result = await session.execute(
                select(UserAccessRequestRecord)
                .where(UserAccessRequestRecord.user_id == normalized_user_id)
                .where(UserAccessRequestRecord.access_type == access_type)
                .where(UserAccessRequestRecord.status == "pending")
                .order_by(UserAccessRequestRecord.created_at.desc())
            )
            existing = existing_result.scalar_one_or_none()
            if existing is not None:
                raise AccessRequestAlreadyPendingError(
                    "A request for this access is already pending review."
                )

            now = datetime.utcnow()
            record = UserAccessRequestRecord(
                id=f"user-access-{uuid4().hex[:12]}",
                user_id=normalized_user_id,
                access_type=access_type,
                reason=reason,
                status="pending",
                reviewed_by_user_id=None,
                review_note=None,
                created_at=now,
                updated_at=now,
            )
            session.add(record)
            await session.commit()
            if user.email and self._email_service.enabled:
                await self._email_service.send_access_request_received_email(
                    to_email=user.email,
                    recipient_name=user.display_name,
                    request_label=self._describe_user_access_type(access_type),
                    request_id=record.id,
                )
            return self._to_access_request_schema(record)

    async def list_user_access_requests(
        self,
        *,
        user_id: str,
    ) -> UserAccessRequestsResponse:
        normalized_user_id = self._normalize_user_id(user_id, generate=False)
        async with self._session_factory() as session:
            await self._load_user_or_raise(session, normalized_user_id)
            result = await session.execute(
                select(UserAccessRequestRecord)
                .where(UserAccessRequestRecord.user_id == normalized_user_id)
                .order_by(UserAccessRequestRecord.created_at.desc())
            )
            items = [self._to_access_request_schema(row) for row in result.scalars().all()]
            return UserAccessRequestsResponse(items=items, total=len(items))

    async def get_user_preferences(self, user_id: str) -> UserPreferences:
        normalized_user_id = self._normalize_user_id(user_id, generate=False)
        async with self._session_factory() as session:
            user = await self._load_user_or_raise(session, normalized_user_id)
            preferences = await self._get_or_create_preferences(
                session=session,
                user_id=user.id,
            )
            await session.commit()
            return self._to_preferences_schema(preferences)

    async def update_user_preferences(
        self,
        user_id: str,
        payload: UpdateUserPreferencesRequest,
    ) -> UserPreferences:
        normalized_user_id = self._normalize_user_id(user_id, generate=False)
        async with self._session_factory() as session:
            user = await self._load_user_or_raise(session, normalized_user_id)
            preferences = await self._get_or_create_preferences(
                session=session,
                user_id=user.id,
            )

            update_data = payload.model_dump(exclude_unset=True)
            if not update_data:
                return self._to_preferences_schema(preferences)

            if "breaking_news_alerts" in update_data and update_data["breaking_news_alerts"] is not None:
                preferences.breaking_news_alerts = bool(update_data["breaking_news_alerts"])
            if "live_stream_alerts" in update_data and update_data["live_stream_alerts"] is not None:
                preferences.live_stream_alerts = bool(update_data["live_stream_alerts"])
            if "comment_replies" in update_data and update_data["comment_replies"] is not None:
                preferences.comment_replies = bool(update_data["comment_replies"])
            if "theme" in update_data and update_data["theme"] is not None:
                preferences.theme = str(update_data["theme"])
            if "text_size" in update_data and update_data["text_size"] is not None:
                preferences.text_size = str(update_data["text_size"])

            preferences.updated_at = datetime.utcnow()
            await session.commit()
            return self._to_preferences_schema(preferences)

    async def _ensure_unique_user(
        self,
        session: AsyncSession,
        *,
        user_id: str,
        email: str | None,
    ) -> None:
        existing_user_result = await session.execute(
            select(UserRecord).where(UserRecord.id == user_id)
        )
        if existing_user_result.scalar_one_or_none() is not None:
            raise UserAlreadyExistsError(f"User id '{user_id}' already exists.")
        await self._ensure_unique_email(session, email=email, exclude_user_id=None)

    async def _load_user_or_raise(
        self,
        session: AsyncSession,
        user_id: str,
    ) -> UserRecord:
        result = await session.execute(select(UserRecord).where(UserRecord.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise UserNotFoundError(f"User '{user_id}' does not exist.")
        return user

    async def _get_or_create_preferences(
        self,
        *,
        session: AsyncSession,
        user_id: str,
    ) -> UserPreferenceRecord:
        result = await session.execute(
            select(UserPreferenceRecord).where(UserPreferenceRecord.user_id == user_id)
        )
        preferences = result.scalar_one_or_none()
        if preferences is not None:
            return preferences

        now = datetime.utcnow()
        preferences = UserPreferenceRecord(
            user_id=user_id,
            breaking_news_alerts=True,
            live_stream_alerts=True,
            comment_replies=True,
            theme="system",
            text_size="small",
            created_at=now,
            updated_at=now,
        )
        session.add(preferences)
        return preferences

    async def _ensure_unique_email(
        self,
        session: AsyncSession,
        *,
        email: str | None,
        exclude_user_id: str | None,
    ) -> None:
        if email is None:
            return
        existing_email_result = await session.execute(
            select(UserRecord).where(func.lower(UserRecord.email) == email.lower())
        )
        existing_user = existing_email_result.scalar_one_or_none()
        if existing_user is None:
            return
        if exclude_user_id and existing_user.id == exclude_user_id:
            return
        raise UserAlreadyExistsError(f"Email '{email}' is already in use.")

    def _normalize_user_id(self, value: str | None, *, generate: bool = True) -> str:
        normalized = self._normalize_text(value, max_length=128)
        if normalized is None:
            if generate:
                return f"user-{uuid4().hex[:12]}"
            raise InvalidUserPayloadError("User id is required.")
        return normalized

    def _normalize_email(self, value: str | None) -> str | None:
        normalized = self._normalize_text(value, max_length=255)
        if normalized is None:
            return None
        if "@" not in normalized:
            raise InvalidUserPayloadError("Email must contain '@'.")
        return normalized.lower()

    def _validate_password(self, value: str | None) -> str:
        password = (value or "").strip()
        if len(password) < 8:
            raise InvalidUserPayloadError("Password must be at least 8 characters.")
        if len(password) > 128:
            raise InvalidUserPayloadError("Password must be 128 characters or fewer.")
        return password

    def _normalize_reset_path(self, value: str | None) -> str:
        candidate = (value or "").strip()
        if not candidate:
            return "/auth/reset-password"
        if not candidate.startswith("/"):
            raise InvalidUserPayloadError("reset_path must start with '/'.")
        return candidate

    def _build_password_reset_url(self, *, reset_path: str, token: str) -> str:
        if reset_path.startswith("/admin"):
            base_url = self._email_admin_web_base_url or self._email_web_base_url
        else:
            base_url = self._email_web_base_url or self._email_admin_web_base_url

        if not base_url:
            return f"{reset_path}?token={quote(token, safe='')}"

        parsed = urlparse(base_url)
        if parsed.scheme and parsed.netloc:
            normalized_base = base_url.rstrip("/")
            target = f"{normalized_base}{reset_path}"
        else:
            target = reset_path

        parsed_target = urlparse(target)
        query_items = parse_qsl(parsed_target.query, keep_blank_values=True)
        query_items = [(key, value) for key, value in query_items if key != "token"]
        query_items.append(("token", token))
        return urlunparse(
            parsed_target._replace(query=urlencode(query_items, doseq=True))
        )

    def _describe_user_access_type(self, access_type: str) -> str:
        return {
            "stream_access": "stream access",
            "stream_hosting": "stream hosting access",
            "contribution_access": "story contribution access",
        }.get(access_type, "additional access")

    def _normalize_text(self, value: str | None, *, max_length: int) -> str | None:
        normalized = (value or "").strip()
        if not normalized:
            return None
        return normalized[:max_length]

    def _hash_password(self, password: str) -> str:
        salt = secrets.token_hex(16)
        iterations = 120_000
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            iterations,
        ).hex()
        return f"pbkdf2_sha256${iterations}${salt}${digest}"

    def _verify_password(self, password: str, password_hash: str) -> bool:
        try:
            algorithm, iterations_raw, salt, expected_digest = password_hash.split("$", 3)
            if algorithm != "pbkdf2_sha256":
                return False
            iterations = int(iterations_raw)
        except ValueError:
            return False

        computed_digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            iterations,
        ).hex()
        return hmac.compare_digest(expected_digest, computed_digest)

    def _issue_access_token(self, *, user_id: str) -> str:
        now = datetime.utcnow()
        expiry = now + timedelta(seconds=self._access_token_ttl_seconds)
        payload = f"{user_id}:{int(expiry.timestamp())}:{secrets.token_hex(8)}"
        signature = hmac.new(
            self._token_secret.encode("utf-8"),
            payload.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        raw_token = f"{payload}:{signature}"
        return base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")

    def _issue_password_reset_token(
        self,
        *,
        user_id: str,
        password_hash: str,
    ) -> str:
        expiry = datetime.utcnow() + timedelta(seconds=self._password_reset_ttl_seconds)
        fingerprint = self._password_hash_fingerprint(password_hash)
        payload = f"{user_id}:{int(expiry.timestamp())}:{fingerprint}:{secrets.token_hex(8)}"
        signature = hmac.new(
            self._token_secret.encode("utf-8"),
            payload.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        raw_token = f"{payload}:{signature}"
        return base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")

    def _decode_password_reset_token(self, token: str) -> dict[str, str]:
        try:
            raw_token = base64.urlsafe_b64decode(token.encode("utf-8")).decode("utf-8")
            user_id, expiry_raw, fingerprint, nonce, signature = raw_token.split(":", 4)
        except Exception as exc:  # noqa: BLE001
            raise PasswordResetTokenError("Reset link is invalid.") from exc

        payload = f"{user_id}:{expiry_raw}:{fingerprint}:{nonce}"
        expected_signature = hmac.new(
            self._token_secret.encode("utf-8"),
            payload.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(expected_signature, signature):
            raise PasswordResetTokenError("Reset link signature is invalid.")

        try:
            expiry = datetime.utcfromtimestamp(int(expiry_raw))
        except ValueError as exc:
            raise PasswordResetTokenError("Reset link is invalid.") from exc
        if expiry < datetime.utcnow():
            raise PasswordResetTokenError("Reset link has expired.")

        return {
            "user_id": user_id,
            "fingerprint": fingerprint,
        }

    def _password_hash_fingerprint(self, password_hash: str) -> str:
        return hashlib.sha256(password_hash.encode("utf-8")).hexdigest()[:16]

    def _to_schema(self, user: UserRecord) -> User:
        return User(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            avatar_url=user.avatar_url,
            is_active=user.is_active,
            role=user.role,
            stream_access_granted=user.stream_access_granted,
            stream_hosting_granted=user.stream_hosting_granted,
            contribution_access_granted=user.contribution_access_granted,
            entitlements=self._entitlements_for_user(
                user=user,
            ),
            created_at=user.created_at,
            updated_at=user.updated_at,
        )

    def _to_access_request_schema(
        self,
        record: UserAccessRequestRecord,
    ) -> UserAccessRequestItem:
        return UserAccessRequestItem(
            id=record.id,
            user_id=record.user_id,
            access_type=record.access_type,
            status=record.status,
            reason=record.reason,
            review_note=record.review_note,
            reviewed_by_user_id=record.reviewed_by_user_id,
            created_at=record.created_at,
            updated_at=record.updated_at,
        )

    def _entitlements_for_user(
        self,
        *,
        user: UserRecord,
    ) -> UserEntitlements:
        role = (user.role or "").strip().lower()
        if not user.is_active:
            return UserEntitlements()
        if role in {"admin", "editor", "contributor"}:
            return UserEntitlements(
                can_access_streams=True,
                can_host_streams=True,
                can_contribute_stories=True,
            )
        return UserEntitlements(
            can_access_streams=user.stream_access_granted,
            can_host_streams=user.stream_hosting_granted,
            can_contribute_stories=user.contribution_access_granted,
        )

    def _user_already_has_access(self, user: UserRecord, access_type: str) -> bool:
        return {
            "stream_access": user.stream_access_granted,
            "stream_hosting": user.stream_hosting_granted,
            "contribution_access": user.contribution_access_granted,
        }.get(access_type, False)

    def _to_preferences_schema(
        self,
        preferences: UserPreferenceRecord,
    ) -> UserPreferences:
        return UserPreferences(
            user_id=preferences.user_id,
            breaking_news_alerts=preferences.breaking_news_alerts,
            live_stream_alerts=preferences.live_stream_alerts,
            comment_replies=preferences.comment_replies,
            theme=preferences.theme,
            text_size=preferences.text_size,
            created_at=preferences.created_at,
            updated_at=preferences.updated_at,
        )
