"""remove enterprise subscription tier

Revision ID: 20260401_0018
Revises: 20260331_0017
Create Date: 2026-04-01 12:10:00
"""

from collections.abc import Sequence

from alembic import op


revision: str = "20260401_0018"
down_revision: str | None = "20260331_0017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        "UPDATE users SET subscription_tier = 'pro' WHERE subscription_tier = 'enterprise'"
    )


def downgrade() -> None:
    op.execute(
        "UPDATE users SET subscription_tier = 'enterprise' WHERE subscription_tier = 'pro'"
    )
