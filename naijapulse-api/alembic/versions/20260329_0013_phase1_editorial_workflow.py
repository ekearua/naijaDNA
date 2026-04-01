"""phase 1 editorial workflow fields

Revision ID: 20260329_0013
Revises: 20260316_0012
Create Date: 2026-03-29 12:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260329_0013"
down_revision: Union[str, None] = "20260316_0012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("role", sa.String(length=32), nullable=False, server_default="user"),
    )
    op.create_index("ix_users_role", "users", ["role"], unique=False)

    op.add_column(
        "news_articles",
        sa.Column("source_domain", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "news_articles",
        sa.Column("source_type", sa.String(length=64), nullable=False, server_default="rss"),
    )
    op.add_column(
        "news_articles",
        sa.Column("created_by_user_id", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "news_articles",
        sa.Column("reviewed_by_user_id", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "news_articles",
        sa.Column("published_by_user_id", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "news_articles",
        sa.Column("status", sa.String(length=32), nullable=False, server_default="published"),
    )
    op.add_column(
        "news_articles",
        sa.Column(
            "verification_status",
            sa.String(length=32),
            nullable=False,
            server_default="unverified",
        ),
    )
    op.add_column(
        "news_articles",
        sa.Column("is_featured", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "news_articles",
        sa.Column("review_notes", sa.Text(), nullable=True),
    )
    op.add_column(
        "news_articles",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )

    op.create_index("ix_news_articles_source_domain", "news_articles", ["source_domain"], unique=False)
    op.create_index("ix_news_articles_source_type", "news_articles", ["source_type"], unique=False)
    op.create_index("ix_news_articles_created_by_user_id", "news_articles", ["created_by_user_id"], unique=False)
    op.create_index("ix_news_articles_reviewed_by_user_id", "news_articles", ["reviewed_by_user_id"], unique=False)
    op.create_index("ix_news_articles_published_by_user_id", "news_articles", ["published_by_user_id"], unique=False)
    op.create_index("ix_news_articles_status", "news_articles", ["status"], unique=False)
    op.create_index("ix_news_articles_verification_status", "news_articles", ["verification_status"], unique=False)
    op.create_index("ix_news_articles_is_featured", "news_articles", ["is_featured"], unique=False)

    op.create_foreign_key(
        "fk_news_articles_created_by_user_id_users",
        "news_articles",
        "users",
        ["created_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_news_articles_reviewed_by_user_id_users",
        "news_articles",
        "users",
        ["reviewed_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_news_articles_published_by_user_id_users",
        "news_articles",
        "users",
        ["published_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.execute("UPDATE news_articles SET created_by_user_id = submitted_by WHERE submitted_by IS NOT NULL")
    op.execute(
        """
        UPDATE news_articles
        SET verification_status = CASE
            WHEN fact_checked THEN 'fact_checked'
            ELSE 'unverified'
        END
        """
    )
    op.execute(
        """
        UPDATE news_articles
        SET source_type = CASE
            WHEN ingestion_provider IN ('user') THEN 'user_submission'
            WHEN ingestion_provider IN ('admin') THEN 'admin_submission'
            WHEN ingestion_provider IN ('newsapi', 'gnews') THEN 'aggregator_api'
            WHEN ingestion_provider LIKE '%_rss' OR ingestion_provider = 'rss' THEN 'rss'
            ELSE 'publisher'
        END
        """
    )
    op.execute(
        """
        UPDATE news_articles
        SET source_domain = left(
            lower(
                split_part(
                    regexp_replace(
                        regexp_replace(coalesce(url, ''), '^https?://', ''),
                        '^www\\.',
                        ''
                    ),
                    '/',
                    1
                )
            ),
            255
        )
        WHERE url IS NOT NULL
        """
    )
    op.execute("UPDATE news_articles SET updated_at = COALESCE(created_at, published_at, CURRENT_TIMESTAMP)")

    op.create_table(
        "article_workflow_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("article_id", sa.String(length=96), nullable=False),
        sa.Column("actor_user_id", sa.String(length=128), nullable=True),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("from_status", sa.String(length=32), nullable=True),
        sa.Column("to_status", sa.String(length=32), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_article_workflow_events_article_id",
        "article_workflow_events",
        ["article_id"],
        unique=False,
    )
    op.create_index(
        "ix_article_workflow_events_actor_user_id",
        "article_workflow_events",
        ["actor_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_article_workflow_events_event_type",
        "article_workflow_events",
        ["event_type"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_article_workflow_events_event_type", table_name="article_workflow_events")
    op.drop_index("ix_article_workflow_events_actor_user_id", table_name="article_workflow_events")
    op.drop_index("ix_article_workflow_events_article_id", table_name="article_workflow_events")
    op.drop_table("article_workflow_events")

    op.drop_constraint("fk_news_articles_published_by_user_id_users", "news_articles", type_="foreignkey")
    op.drop_constraint("fk_news_articles_reviewed_by_user_id_users", "news_articles", type_="foreignkey")
    op.drop_constraint("fk_news_articles_created_by_user_id_users", "news_articles", type_="foreignkey")

    op.drop_index("ix_news_articles_is_featured", table_name="news_articles")
    op.drop_index("ix_news_articles_verification_status", table_name="news_articles")
    op.drop_index("ix_news_articles_status", table_name="news_articles")
    op.drop_index("ix_news_articles_published_by_user_id", table_name="news_articles")
    op.drop_index("ix_news_articles_reviewed_by_user_id", table_name="news_articles")
    op.drop_index("ix_news_articles_created_by_user_id", table_name="news_articles")
    op.drop_index("ix_news_articles_source_type", table_name="news_articles")
    op.drop_index("ix_news_articles_source_domain", table_name="news_articles")

    op.drop_column("news_articles", "updated_at")
    op.drop_column("news_articles", "review_notes")
    op.drop_column("news_articles", "is_featured")
    op.drop_column("news_articles", "verification_status")
    op.drop_column("news_articles", "status")
    op.drop_column("news_articles", "published_by_user_id")
    op.drop_column("news_articles", "reviewed_by_user_id")
    op.drop_column("news_articles", "created_by_user_id")
    op.drop_column("news_articles", "source_type")
    op.drop_column("news_articles", "source_domain")

    op.drop_index("ix_users_role", table_name="users")
    op.drop_column("users", "role")
