"""add article tags

Revision ID: 20260402_0021
Revises: 20260401_0020
Create Date: 2026-04-02 11:20:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260402_0021"
down_revision: str | None = "20260401_0020"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "article_tags",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("article_id", sa.String(length=96), nullable=False),
        sa.Column("tag", sa.String(length=120), nullable=False),
        sa.Column("normalized_tag", sa.String(length=120), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "article_id",
            "normalized_tag",
            name="uq_article_tags_article_normalized_tag",
        ),
    )
    op.create_index("ix_article_tags_article_id", "article_tags", ["article_id"], unique=False)
    op.create_index(
        "ix_article_tags_normalized_tag",
        "article_tags",
        ["normalized_tag"],
        unique=False,
    )

    op.execute(
        sa.text(
            """
            INSERT INTO article_tags (article_id, tag, normalized_tag, created_at)
            SELECT
                id,
                TRIM(category),
                LOWER(TRIM(category)),
                COALESCE(updated_at, created_at)
            FROM news_articles
            WHERE category IS NOT NULL
              AND TRIM(category) <> ''
            """
        )
    )


def downgrade() -> None:
    op.drop_index("ix_article_tags_normalized_tag", table_name="article_tags")
    op.drop_index("ix_article_tags_article_id", table_name="article_tags")
    op.drop_table("article_tags")
