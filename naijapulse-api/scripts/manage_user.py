from __future__ import annotations

import argparse
import asyncio
import getpass
import hashlib
import secrets
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from sqlalchemy import func, select

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.core.config import get_settings
from app.db.models import UserPreferenceRecord, UserRecord
from app.db.session import DatabaseSessionManager


VALID_ROLES = ("user", "contributor", "moderator", "editor", "admin")


@dataclass(slots=True)
class UserMutationResult:
    action: str
    user_id: str
    email: str
    role: str
    is_active: bool


def build_parser(default_role: str | None = None) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Create or update a local NaijaPulse user for testing.",
    )
    parser.add_argument("--email", required=True, help="User email address.")
    parser.add_argument("--password", help="Plain-text password to set.")
    parser.add_argument("--name", help="Display name for the user.")
    parser.add_argument("--id", dest="user_id", help="Optional explicit user id.")
    parser.add_argument(
        "--role",
        choices=VALID_ROLES,
        default=default_role or "user",
        help="Target role to assign.",
    )
    parser.add_argument(
        "--stream-access",
        action="store_true",
        help="Grant stream viewing access.",
    )
    parser.add_argument(
        "--stream-hosting",
        action="store_true",
        help="Grant stream hosting access.",
    )
    parser.add_argument(
        "--contribution-access",
        action="store_true",
        help="Grant contribution access.",
    )
    parser.add_argument(
        "--inactive",
        action="store_true",
        help="Create or update the account as inactive.",
    )
    parser.add_argument(
        "--prompt-password",
        action="store_true",
        help="Prompt for a password even if --password was provided.",
    )
    return parser


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    iterations = 120_000
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations,
    ).hex()
    return f"pbkdf2_sha256${iterations}${salt}${digest}"


def normalize_email(value: str) -> str:
    email = value.strip().lower()
    if "@" not in email:
        raise ValueError("Email must contain '@'.")
    if len(email) > 255:
        raise ValueError("Email must be 255 characters or fewer.")
    return email


def normalize_password(value: str) -> str:
    password = value.strip()
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters.")
    if len(password) > 128:
        raise ValueError("Password must be 128 characters or fewer.")
    return password


def resolve_password(args: argparse.Namespace) -> str:
    if args.prompt_password or not args.password:
        first = getpass.getpass("Password: ")
        second = getpass.getpass("Confirm password: ")
        if first != second:
            raise ValueError("Passwords do not match.")
        return normalize_password(first)
    return normalize_password(args.password)


async def ensure_user_preferences(session, user_id: str) -> None:
    result = await session.execute(
        select(UserPreferenceRecord).where(UserPreferenceRecord.user_id == user_id)
    )
    preferences = result.scalar_one_or_none()
    if preferences is not None:
        return

    now = datetime.utcnow()
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


async def create_or_update_user(args: argparse.Namespace) -> UserMutationResult:
    settings = get_settings()
    db = DatabaseSessionManager(settings.database_url, echo=settings.database_echo)
    email = normalize_email(args.email)
    password_hash = hash_password(resolve_password(args))
    display_name = (args.name or "").strip() or email.split("@", 1)[0]
    role = args.role
    is_active = not args.inactive
    user_id = (args.user_id or "").strip() or f"user-{secrets.token_hex(6)}"
    stream_access_granted = bool(args.stream_access or args.stream_hosting)
    stream_hosting_granted = bool(args.stream_hosting)
    contribution_access_granted = bool(args.contribution_access)

    try:
        async with db.session() as session:
            existing = None
            result = await session.execute(
                select(UserRecord).where(func.lower(UserRecord.email) == email.lower())
            )
            existing = result.scalar_one_or_none()
            if existing is None and args.user_id:
                existing = await session.get(UserRecord, user_id)

            now = datetime.utcnow()
            if existing is None:
                user = UserRecord(
                    id=user_id,
                    email=email,
                    password_hash=password_hash,
                    display_name=display_name,
                    avatar_url=None,
                    is_active=is_active,
                    role=role,
                    subscription_tier="free",
                    stream_access_granted=stream_access_granted,
                    stream_hosting_granted=stream_hosting_granted,
                    contribution_access_granted=contribution_access_granted,
                    subscription_started_at=None,
                    subscription_expires_at=None,
                    created_at=now,
                    updated_at=now,
                )
                session.add(user)
                await ensure_user_preferences(session, user.id)
                action = "created"
            else:
                existing.email = email
                existing.password_hash = password_hash
                existing.display_name = display_name
                existing.is_active = is_active
                existing.role = role
                existing.stream_access_granted = stream_access_granted
                existing.stream_hosting_granted = stream_hosting_granted
                existing.contribution_access_granted = contribution_access_granted
                existing.updated_at = now
                await ensure_user_preferences(session, existing.id)
                user = existing
                action = "updated"

            await session.commit()
            return UserMutationResult(
                action=action,
                user_id=user.id,
                email=user.email or email,
                role=user.role,
                is_active=user.is_active,
            )
    finally:
        await db.dispose()


def main(default_role: str | None = None) -> int:
    parser = build_parser(default_role=default_role)
    args = parser.parse_args()
    try:
        result = asyncio.run(create_or_update_user(args))
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    status = "active" if result.is_active else "inactive"
    print(
        f"User {result.action}: {result.email} ({result.user_id}) role={result.role} status={status}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
