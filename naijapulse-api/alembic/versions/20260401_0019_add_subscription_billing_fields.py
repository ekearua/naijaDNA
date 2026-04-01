"""add subscription billing fields

Revision ID: 20260401_0019
Revises: 20260401_0018
Create Date: 2026-04-01 12:45:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260401_0019"
down_revision: str | None = "20260401_0018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("billing_provider", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("provider_customer_id", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("provider_subscription_id", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "subscription_status",
            sa.String(length=32),
            nullable=False,
            server_default="inactive",
        ),
    )
    op.add_column(
        "users",
        sa.Column("current_period_start", sa.DateTime(timezone=False), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("current_period_end", sa.DateTime(timezone=False), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "cancel_at_period_end",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "users",
        sa.Column("last_payment_at", sa.DateTime(timezone=False), nullable=True),
    )
    op.create_index(
        "ix_users_subscription_status",
        "users",
        ["subscription_status"],
        unique=False,
    )

    op.execute(
        """
        UPDATE users
        SET subscription_status = 'active',
            current_period_start = COALESCE(subscription_started_at, created_at),
            current_period_end = subscription_expires_at
        WHERE subscription_tier IN ('premium', 'pro')
        """
    )


def downgrade() -> None:
    op.drop_index("ix_users_subscription_status", table_name="users")
    op.drop_column("users", "last_payment_at")
    op.drop_column("users", "cancel_at_period_end")
    op.drop_column("users", "current_period_end")
    op.drop_column("users", "current_period_start")
    op.drop_column("users", "subscription_status")
    op.drop_column("users", "provider_subscription_id")
    op.drop_column("users", "provider_customer_id")
    op.drop_column("users", "billing_provider")
