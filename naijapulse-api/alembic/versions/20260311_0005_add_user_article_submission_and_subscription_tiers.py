"""add user article submission fields and subscription tiers

Revision ID: 20260311_0005
Revises: 20260311_0004
Create Date: 2026-03-11 14:20:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260311_0005"
down_revision: Union[str, None] = "20260311_0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("subscription_tier", sa.String(length=32), nullable=False, server_default="free"),
    )
    op.add_column(
        "users",
        sa.Column("subscription_started_at", sa.DateTime(timezone=False), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("subscription_expires_at", sa.DateTime(timezone=False), nullable=True),
    )
    op.create_index("ix_users_subscription_tier", "users", ["subscription_tier"], unique=False)
    op.alter_column("users", "subscription_tier", server_default=None)

    op.add_column("news_articles", sa.Column("submitted_by", sa.String(length=128), nullable=True))
    op.add_column(
        "news_articles",
        sa.Column("is_user_generated", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index(
        "ix_news_articles_submitted_by",
        "news_articles",
        ["submitted_by"],
        unique=False,
    )
    op.create_index(
        "ix_news_articles_is_user_generated",
        "news_articles",
        ["is_user_generated"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_news_articles_submitted_by_users",
        "news_articles",
        "users",
        ["submitted_by"],
        ["id"],
        ondelete="SET NULL",
    )
    op.alter_column("news_articles", "is_user_generated", server_default=None)


def downgrade() -> None:
    op.drop_constraint("fk_news_articles_submitted_by_users", "news_articles", type_="foreignkey")
    op.drop_index("ix_news_articles_is_user_generated", table_name="news_articles")
    op.drop_index("ix_news_articles_submitted_by", table_name="news_articles")
    op.drop_column("news_articles", "is_user_generated")
    op.drop_column("news_articles", "submitted_by")

    op.drop_index("ix_users_subscription_tier", table_name="users")
    op.drop_column("users", "subscription_expires_at")
    op.drop_column("users", "subscription_started_at")
    op.drop_column("users", "subscription_tier")
