"""add live update pages and entries

Revision ID: 20260406_0023
Revises: 20260406_0022
Create Date: 2026-04-06 23:10:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260406_0023"
down_revision: str | None = "20260406_0022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "live_update_pages",
        sa.Column("id", sa.String(length=96), nullable=False),
        sa.Column("slug", sa.String(length=160), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("hero_kicker", sa.String(length=120), nullable=True),
        sa.Column("category", sa.String(length=120), nullable=False),
        sa.Column("cover_image_url", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("is_featured", sa.Boolean(), nullable=False),
        sa.Column("is_breaking", sa.Boolean(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("last_published_entry_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("created_by_user_id", sa.String(length=128), nullable=True),
        sa.Column("updated_by_user_id", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
            name="fk_live_update_pages_created_by_user_id_users",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
            name="fk_live_update_pages_updated_by_user_id_users",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )
    op.create_index(
        "ix_live_update_pages_slug",
        "live_update_pages",
        ["slug"],
        unique=True,
    )
    op.create_index(
        "ix_live_update_pages_category",
        "live_update_pages",
        ["category"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_status",
        "live_update_pages",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_is_featured",
        "live_update_pages",
        ["is_featured"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_is_breaking",
        "live_update_pages",
        ["is_breaking"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_started_at",
        "live_update_pages",
        ["started_at"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_ended_at",
        "live_update_pages",
        ["ended_at"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_last_published_entry_at",
        "live_update_pages",
        ["last_published_entry_at"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_created_by_user_id",
        "live_update_pages",
        ["created_by_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_pages_updated_by_user_id",
        "live_update_pages",
        ["updated_by_user_id"],
        unique=False,
    )

    op.create_table(
        "live_update_entries",
        sa.Column("id", sa.String(length=96), nullable=False),
        sa.Column("page_id", sa.String(length=96), nullable=False),
        sa.Column("block_type", sa.String(length=32), nullable=False),
        sa.Column("headline", sa.String(length=255), nullable=True),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("image_caption", sa.Text(), nullable=True),
        sa.Column("linked_article_id", sa.String(length=96), nullable=True),
        sa.Column("linked_poll_id", sa.String(length=80), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("display_order", sa.Integer(), nullable=False),
        sa.Column("is_pinned", sa.Boolean(), nullable=False),
        sa.Column("is_visible", sa.Boolean(), nullable=False),
        sa.Column("created_by_user_id", sa.String(length=128), nullable=True),
        sa.Column("updated_by_user_id", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(
            ["page_id"],
            ["live_update_pages.id"],
            ondelete="CASCADE",
            name="fk_live_update_entries_page_id_live_update_pages",
        ),
        sa.ForeignKeyConstraint(
            ["linked_article_id"],
            ["news_articles.id"],
            ondelete="SET NULL",
            name="fk_live_update_entries_linked_article_id_news_articles",
        ),
        sa.ForeignKeyConstraint(
            ["linked_poll_id"],
            ["polls.id"],
            ondelete="SET NULL",
            name="fk_live_update_entries_linked_poll_id_polls",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
            name="fk_live_update_entries_created_by_user_id_users",
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
            name="fk_live_update_entries_updated_by_user_id_users",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_live_update_entries_page_id",
        "live_update_entries",
        ["page_id"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_block_type",
        "live_update_entries",
        ["block_type"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_linked_article_id",
        "live_update_entries",
        ["linked_article_id"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_linked_poll_id",
        "live_update_entries",
        ["linked_poll_id"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_published_at",
        "live_update_entries",
        ["published_at"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_display_order",
        "live_update_entries",
        ["display_order"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_is_pinned",
        "live_update_entries",
        ["is_pinned"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_is_visible",
        "live_update_entries",
        ["is_visible"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_created_by_user_id",
        "live_update_entries",
        ["created_by_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_live_update_entries_updated_by_user_id",
        "live_update_entries",
        ["updated_by_user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_live_update_entries_updated_by_user_id", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_created_by_user_id", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_is_visible", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_is_pinned", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_display_order", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_published_at", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_linked_poll_id", table_name="live_update_entries")
    op.drop_index(
        "ix_live_update_entries_linked_article_id",
        table_name="live_update_entries",
    )
    op.drop_index("ix_live_update_entries_block_type", table_name="live_update_entries")
    op.drop_index("ix_live_update_entries_page_id", table_name="live_update_entries")
    op.drop_table("live_update_entries")

    op.drop_index("ix_live_update_pages_updated_by_user_id", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_created_by_user_id", table_name="live_update_pages")
    op.drop_index(
        "ix_live_update_pages_last_published_entry_at",
        table_name="live_update_pages",
    )
    op.drop_index("ix_live_update_pages_ended_at", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_started_at", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_is_breaking", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_is_featured", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_status", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_category", table_name="live_update_pages")
    op.drop_index("ix_live_update_pages_slug", table_name="live_update_pages")
    op.drop_table("live_update_pages")
