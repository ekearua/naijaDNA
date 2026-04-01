"""add users model and related relationship tables

Revision ID: 20260311_0004
Revises: 20260311_0003
Create Date: 2026-03-11 11:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260311_0004"
down_revision: Union[str, None] = "20260311_0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=128), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("display_name", sa.String(length=120), nullable=True),
        sa.Column("avatar_url", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "user_preferences",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("breaking_news_alerts", sa.Boolean(), nullable=False),
        sa.Column("live_stream_alerts", sa.Boolean(), nullable=False),
        sa.Column("comment_replies", sa.Boolean(), nullable=False),
        sa.Column("theme", sa.String(length=32), nullable=False),
        sa.Column("text_size", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", name="uq_user_preferences_user_id"),
    )
    op.create_index("ix_user_preferences_user_id", "user_preferences", ["user_id"], unique=False)

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=24), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token", name="uq_device_tokens_token"),
    )
    op.create_index("ix_device_tokens_user_id", "device_tokens", ["user_id"], unique=False)

    op.create_table(
        "user_bookmarks",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("article_id", sa.String(length=96), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "article_id", name="uq_user_bookmark"),
    )
    op.create_index("ix_user_bookmarks_user_id", "user_bookmarks", ["user_id"], unique=False)
    op.create_index("ix_user_bookmarks_article_id", "user_bookmarks", ["article_id"], unique=False)

    op.create_table(
        "user_category_interests",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("category_id", sa.String(length=80), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "category_id", name="uq_user_category_interest"),
    )
    op.create_index(
        "ix_user_category_interests_user_id",
        "user_category_interests",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_category_interests_category_id",
        "user_category_interests",
        ["category_id"],
        unique=False,
    )

    # Existing poll rows may contain placeholder values that are not user ids.
    op.execute("UPDATE polls SET created_by = NULL WHERE created_by IS NOT NULL")
    op.create_foreign_key(
        "fk_polls_created_by_users",
        "polls",
        "users",
        ["created_by"],
        ["id"],
        ondelete="SET NULL",
    )

    op.add_column("poll_votes", sa.Column("user_id", sa.String(length=128), nullable=True))
    op.create_index("ix_poll_votes_user_id", "poll_votes", ["user_id"], unique=False)
    op.create_foreign_key(
        "fk_poll_votes_user_id_users",
        "poll_votes",
        "users",
        ["user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_unique_constraint(
        "uq_poll_vote_per_user",
        "poll_votes",
        ["poll_id", "user_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_poll_vote_per_user", "poll_votes", type_="unique")
    op.drop_constraint("fk_poll_votes_user_id_users", "poll_votes", type_="foreignkey")
    op.drop_index("ix_poll_votes_user_id", table_name="poll_votes")
    op.drop_column("poll_votes", "user_id")

    op.drop_constraint("fk_polls_created_by_users", "polls", type_="foreignkey")

    op.drop_index("ix_user_category_interests_category_id", table_name="user_category_interests")
    op.drop_index("ix_user_category_interests_user_id", table_name="user_category_interests")
    op.drop_table("user_category_interests")

    op.drop_index("ix_user_bookmarks_article_id", table_name="user_bookmarks")
    op.drop_index("ix_user_bookmarks_user_id", table_name="user_bookmarks")
    op.drop_table("user_bookmarks")

    op.drop_index("ix_device_tokens_user_id", table_name="device_tokens")
    op.drop_table("device_tokens")

    op.drop_index("ix_user_preferences_user_id", table_name="user_preferences")
    op.drop_table("user_preferences")

    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
