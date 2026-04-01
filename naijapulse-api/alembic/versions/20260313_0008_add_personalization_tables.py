"""add personalization tables for feed ranking and preferences

Revision ID: 20260313_0008
Revises: 20260312_0007
Create Date: 2026-03-13 09:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260313_0008"
down_revision: Union[str, None] = "20260312_0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_interest_profiles",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("category_id", sa.String(length=80), nullable=False),
        sa.Column("explicit_weight", sa.Float(), nullable=False),
        sa.Column("implicit_weight", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "category_id", name="uq_user_interest_profile"),
    )
    op.create_index(
        "ix_user_interest_profiles_user_id",
        "user_interest_profiles",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_interest_profiles_category_id",
        "user_interest_profiles",
        ["category_id"],
        unique=False,
    )

    op.create_table(
        "user_topic_follows",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("topic", sa.String(length=120), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "topic", name="uq_user_topic_follow"),
    )
    op.create_index("ix_user_topic_follows_user_id", "user_topic_follows", ["user_id"], unique=False)
    op.create_index("ix_user_topic_follows_topic", "user_topic_follows", ["topic"], unique=False)

    op.create_table(
        "feed_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("article_id", sa.String(length=96), nullable=True),
        sa.Column("category_id", sa.String(length=80), nullable=True),
        sa.Column("source", sa.String(length=255), nullable=True),
        sa.Column("event_type", sa.String(length=32), nullable=False),
        sa.Column("dwell_ms", sa.Integer(), nullable=True),
        sa.Column("idempotency_key", sa.String(length=160), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("idempotency_key", name="uq_feed_event_idempotency_key"),
    )
    op.create_index("ix_feed_events_user_id", "feed_events", ["user_id"], unique=False)
    op.create_index("ix_feed_events_article_id", "feed_events", ["article_id"], unique=False)
    op.create_index("ix_feed_events_category_id", "feed_events", ["category_id"], unique=False)
    op.create_index("ix_feed_events_source", "feed_events", ["source"], unique=False)
    op.create_index("ix_feed_events_event_type", "feed_events", ["event_type"], unique=False)
    op.create_index("ix_feed_events_created_at", "feed_events", ["created_at"], unique=False)

    op.create_table(
        "user_hidden_items",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("article_id", sa.String(length=96), nullable=True),
        sa.Column("source", sa.String(length=255), nullable=True),
        sa.Column("category_id", sa.String(length=80), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "article_id", name="uq_user_hidden_article"),
        sa.UniqueConstraint("user_id", "source", name="uq_user_hidden_source"),
        sa.UniqueConstraint("user_id", "category_id", name="uq_user_hidden_category"),
    )
    op.create_index("ix_user_hidden_items_user_id", "user_hidden_items", ["user_id"], unique=False)
    op.create_index("ix_user_hidden_items_article_id", "user_hidden_items", ["article_id"], unique=False)
    op.create_index("ix_user_hidden_items_source", "user_hidden_items", ["source"], unique=False)
    op.create_index("ix_user_hidden_items_category_id", "user_hidden_items", ["category_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_user_hidden_items_category_id", table_name="user_hidden_items")
    op.drop_index("ix_user_hidden_items_source", table_name="user_hidden_items")
    op.drop_index("ix_user_hidden_items_article_id", table_name="user_hidden_items")
    op.drop_index("ix_user_hidden_items_user_id", table_name="user_hidden_items")
    op.drop_table("user_hidden_items")

    op.drop_index("ix_feed_events_created_at", table_name="feed_events")
    op.drop_index("ix_feed_events_event_type", table_name="feed_events")
    op.drop_index("ix_feed_events_source", table_name="feed_events")
    op.drop_index("ix_feed_events_category_id", table_name="feed_events")
    op.drop_index("ix_feed_events_article_id", table_name="feed_events")
    op.drop_index("ix_feed_events_user_id", table_name="feed_events")
    op.drop_table("feed_events")

    op.drop_index("ix_user_topic_follows_topic", table_name="user_topic_follows")
    op.drop_index("ix_user_topic_follows_user_id", table_name="user_topic_follows")
    op.drop_table("user_topic_follows")

    op.drop_index("ix_user_interest_profiles_category_id", table_name="user_interest_profiles")
    op.drop_index("ix_user_interest_profiles_user_id", table_name="user_interest_profiles")
    op.drop_table("user_interest_profiles")
