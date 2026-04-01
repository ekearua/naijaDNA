"""add homepage configuration tables

Revision ID: 20260331_0017
Revises: 20260331_0016
Create Date: 2026-03-31 18:10:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260331_0017"
down_revision: str | None = "20260331_0016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "homepage_categories",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("label", sa.String(length=120), nullable=False),
        sa.Column("color_hex", sa.String(length=7), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_homepage_categories_position",
        "homepage_categories",
        ["position"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_categories_enabled",
        "homepage_categories",
        ["enabled"],
        unique=False,
    )

    op.create_table(
        "homepage_secondary_chips",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("label", sa.String(length=120), nullable=False),
        sa.Column("chip_type", sa.String(length=32), nullable=False),
        sa.Column("color_hex", sa.String(length=7), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_homepage_secondary_chips_chip_type",
        "homepage_secondary_chips",
        ["chip_type"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_secondary_chips_position",
        "homepage_secondary_chips",
        ["position"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_secondary_chips_enabled",
        "homepage_secondary_chips",
        ["enabled"],
        unique=False,
    )

    op.create_table(
        "homepage_story_placements",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("article_id", sa.String(length=96), nullable=False),
        sa.Column("section", sa.String(length=32), nullable=False),
        sa.Column("target_key", sa.String(length=80), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(
            ["article_id"],
            ["news_articles.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "article_id",
            "section",
            "target_key",
            name="uq_homepage_story_section_target",
        ),
    )
    op.create_index(
        "ix_homepage_story_placements_article_id",
        "homepage_story_placements",
        ["article_id"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_story_placements_section",
        "homepage_story_placements",
        ["section"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_story_placements_target_key",
        "homepage_story_placements",
        ["target_key"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_story_placements_position",
        "homepage_story_placements",
        ["position"],
        unique=False,
    )
    op.create_index(
        "ix_homepage_story_placements_enabled",
        "homepage_story_placements",
        ["enabled"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_homepage_story_placements_enabled", table_name="homepage_story_placements")
    op.drop_index("ix_homepage_story_placements_position", table_name="homepage_story_placements")
    op.drop_index("ix_homepage_story_placements_target_key", table_name="homepage_story_placements")
    op.drop_index("ix_homepage_story_placements_section", table_name="homepage_story_placements")
    op.drop_index("ix_homepage_story_placements_article_id", table_name="homepage_story_placements")
    op.drop_table("homepage_story_placements")

    op.drop_index("ix_homepage_secondary_chips_enabled", table_name="homepage_secondary_chips")
    op.drop_index("ix_homepage_secondary_chips_position", table_name="homepage_secondary_chips")
    op.drop_index("ix_homepage_secondary_chips_chip_type", table_name="homepage_secondary_chips")
    op.drop_table("homepage_secondary_chips")

    op.drop_index("ix_homepage_categories_enabled", table_name="homepage_categories")
    op.drop_index("ix_homepage_categories_position", table_name="homepage_categories")
    op.drop_table("homepage_categories")
