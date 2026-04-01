"""add comment reactions table

Revision ID: 20260330_0015
Revises: 20260329_0014
Create Date: 2026-03-30 11:20:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260330_0015"
down_revision: str | None = "20260329_0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "comment_reactions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("comment_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("reaction_type", sa.String(length=32), nullable=False, server_default="like"),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(
            ["comment_id"],
            ["article_comments.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "comment_id",
            "user_id",
            "reaction_type",
            name="uq_comment_reaction_per_user",
        ),
    )
    op.create_index(
        "ix_comment_reactions_comment_id",
        "comment_reactions",
        ["comment_id"],
        unique=False,
    )
    op.create_index(
        "ix_comment_reactions_user_id",
        "comment_reactions",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_comment_reactions_reaction_type",
        "comment_reactions",
        ["reaction_type"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_comment_reactions_reaction_type", table_name="comment_reactions")
    op.drop_index("ix_comment_reactions_user_id", table_name="comment_reactions")
    op.drop_index("ix_comment_reactions_comment_id", table_name="comment_reactions")
    op.drop_table("comment_reactions")
