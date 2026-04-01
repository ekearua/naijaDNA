"""init postgres schema

Revision ID: 20260305_0001
Revises:
Create Date: 2026-03-05 12:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260305_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "news_articles",
        sa.Column("id", sa.String(length=96), nullable=False),
        sa.Column("fingerprint", sa.String(length=40), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=False),
        sa.Column("source", sa.String(length=255), nullable=False),
        sa.Column("category", sa.String(length=120), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("url", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("fact_checked", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_news_articles_category", "news_articles", ["category"], unique=False)
    op.create_index("ix_news_articles_fingerprint", "news_articles", ["fingerprint"], unique=True)
    op.create_index("ix_news_articles_published_at", "news_articles", ["published_at"], unique=False)

    op.create_table(
        "news_sources",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("type", sa.String(length=80), nullable=False),
        sa.Column("country", sa.String(length=8), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("requires_api_key", sa.Boolean(), nullable=False),
        sa.Column("configured", sa.Boolean(), nullable=False),
        sa.Column("feed_url", sa.Text(), nullable=True),
        sa.Column("api_base_url", sa.Text(), nullable=True),
        sa.Column("poll_interval_sec", sa.Integer(), nullable=False),
        sa.Column("last_run_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "polls",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("question", sa.Text(), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_polls_ends_at", "polls", ["ends_at"], unique=False)

    op.create_table(
        "poll_options",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("poll_id", sa.String(length=80), nullable=False),
        sa.Column("option_id", sa.String(length=80), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("votes", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["poll_id"], ["polls.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("poll_id", "option_id", name="uq_poll_option"),
    )
    op.create_index("ix_poll_options_poll_id", "poll_options", ["poll_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_poll_options_poll_id", table_name="poll_options")
    op.drop_table("poll_options")

    op.drop_index("ix_polls_ends_at", table_name="polls")
    op.drop_table("polls")

    op.drop_table("news_sources")

    op.drop_index("ix_news_articles_published_at", table_name="news_articles")
    op.drop_index("ix_news_articles_fingerprint", table_name="news_articles")
    op.drop_index("ix_news_articles_category", table_name="news_articles")
    op.drop_table("news_articles")

