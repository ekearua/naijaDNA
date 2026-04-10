"""add article queue settings

Revision ID: 20260408_0027
Revises: 20260408_0026
Create Date: 2026-04-08 18:40:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260408_0027"
down_revision = "20260408_0026"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "article_queue_settings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column(
            "auto_archive_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column(
            "archive_draft_after_days",
            sa.Integer(),
            nullable=False,
            server_default="30",
        ),
        sa.Column(
            "archive_review_after_days",
            sa.Integer(),
            nullable=False,
            server_default="14",
        ),
        sa.Column(
            "archive_rejected_after_days",
            sa.Integer(),
            nullable=False,
            server_default="14",
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.execute(
        sa.text(
            """
            INSERT INTO article_queue_settings (
                id,
                auto_archive_enabled,
                archive_draft_after_days,
                archive_review_after_days,
                archive_rejected_after_days,
                created_at,
                updated_at
            ) VALUES (
                1,
                true,
                30,
                14,
                14,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            )
            """
        )
    )

    op.alter_column("article_queue_settings", "auto_archive_enabled", server_default=None)
    op.alter_column(
        "article_queue_settings",
        "archive_draft_after_days",
        server_default=None,
    )
    op.alter_column(
        "article_queue_settings",
        "archive_review_after_days",
        server_default=None,
    )
    op.alter_column(
        "article_queue_settings",
        "archive_rejected_after_days",
        server_default=None,
    )


def downgrade() -> None:
    op.drop_table("article_queue_settings")
