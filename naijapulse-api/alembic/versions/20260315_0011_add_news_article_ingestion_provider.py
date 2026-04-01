"""add ingestion provider to news articles

Revision ID: 20260315_0011
Revises: 20260315_0010
Create Date: 2026-03-15
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260315_0011"
down_revision = "20260315_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "news_articles",
        sa.Column("ingestion_provider", sa.String(length=80), nullable=True),
    )
    op.create_index(
        "ix_news_articles_ingestion_provider",
        "news_articles",
        ["ingestion_provider"],
        unique=False,
    )

    op.execute(
        """
        UPDATE news_articles
        SET ingestion_provider = CASE
            WHEN id LIKE 'gnews-%' THEN 'gnews'
            WHEN id LIKE 'newsapi-%' THEN 'newsapi'
            WHEN id LIKE 'premium_times_rss-%' THEN 'premium_times_rss'
            WHEN id LIKE 'guardian_ng_rss-%' THEN 'guardian_ng_rss'
            WHEN id LIKE 'google_news_business_rss-%' THEN 'google_news_business_rss'
            WHEN id LIKE 'google_news_sports_rss-%' THEN 'google_news_sports_rss'
            WHEN id LIKE 'google_news_technology_rss-%' THEN 'google_news_technology_rss'
            WHEN id LIKE 'google_news_rss-%' THEN 'google_news_rss'
            WHEN id LIKE 'user-article-%' THEN 'user'
            ELSE 'unknown'
        END
        WHERE ingestion_provider IS NULL
        """
    )


def downgrade() -> None:
    op.drop_index("ix_news_articles_ingestion_provider", table_name="news_articles")
    op.drop_column("news_articles", "ingestion_provider")
