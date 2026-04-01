"""add article comments and notifications

Revision ID: 20260329_0014
Revises: 20260329_0013
Create Date: 2026-03-29 18:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260329_0014"
down_revision: Union[str, None] = "20260329_0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "article_comments",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("article_id", sa.String(length=96), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=True),
        sa.Column("parent_comment_id", sa.Integer(), nullable=True),
        sa.Column("author_name", sa.String(length=120), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="visible"),
        sa.Column("reply_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("like_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("moderated_by_user_id", sa.String(length=128), nullable=True),
        sa.Column("moderated_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("moderation_reason", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["parent_comment_id"], ["article_comments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["moderated_by_user_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_article_comments_article_id", "article_comments", ["article_id"], unique=False)
    op.create_index("ix_article_comments_user_id", "article_comments", ["user_id"], unique=False)
    op.create_index("ix_article_comments_parent_comment_id", "article_comments", ["parent_comment_id"], unique=False)
    op.create_index("ix_article_comments_status", "article_comments", ["status"], unique=False)
    op.create_index("ix_article_comments_moderated_by_user_id", "article_comments", ["moderated_by_user_id"], unique=False)
    op.create_index("ix_article_comments_created_at", "article_comments", ["created_at"], unique=False)

    op.create_table(
        "comment_reports",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("comment_id", sa.Integer(), nullable=False),
        sa.Column("reporter_user_id", sa.String(length=128), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["comment_id"], ["article_comments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("comment_id", "reporter_user_id", name="uq_comment_report_per_user"),
    )
    op.create_index("ix_comment_reports_comment_id", "comment_reports", ["comment_id"], unique=False)
    op.create_index("ix_comment_reports_reporter_user_id", "comment_reports", ["reporter_user_id"], unique=False)

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("type", sa.String(length=48), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("actor_user_id", sa.String(length=128), nullable=True),
        sa.Column("actor_name", sa.String(length=120), nullable=True),
        sa.Column("article_id", sa.String(length=96), nullable=True),
        sa.Column("comment_id", sa.Integer(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["article_id"], ["news_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["comment_id"], ["article_comments.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"], unique=False)
    op.create_index("ix_notifications_type", "notifications", ["type"], unique=False)
    op.create_index("ix_notifications_actor_user_id", "notifications", ["actor_user_id"], unique=False)
    op.create_index("ix_notifications_article_id", "notifications", ["article_id"], unique=False)
    op.create_index("ix_notifications_comment_id", "notifications", ["comment_id"], unique=False)
    op.create_index("ix_notifications_is_read", "notifications", ["is_read"], unique=False)
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_notifications_created_at", table_name="notifications")
    op.drop_index("ix_notifications_is_read", table_name="notifications")
    op.drop_index("ix_notifications_comment_id", table_name="notifications")
    op.drop_index("ix_notifications_article_id", table_name="notifications")
    op.drop_index("ix_notifications_actor_user_id", table_name="notifications")
    op.drop_index("ix_notifications_type", table_name="notifications")
    op.drop_index("ix_notifications_user_id", table_name="notifications")
    op.drop_table("notifications")

    op.drop_index("ix_comment_reports_reporter_user_id", table_name="comment_reports")
    op.drop_index("ix_comment_reports_comment_id", table_name="comment_reports")
    op.drop_table("comment_reports")

    op.drop_index("ix_article_comments_created_at", table_name="article_comments")
    op.drop_index("ix_article_comments_moderated_by_user_id", table_name="article_comments")
    op.drop_index("ix_article_comments_status", table_name="article_comments")
    op.drop_index("ix_article_comments_parent_comment_id", table_name="article_comments")
    op.drop_index("ix_article_comments_user_id", table_name="article_comments")
    op.drop_index("ix_article_comments_article_id", table_name="article_comments")
    op.drop_table("article_comments")
