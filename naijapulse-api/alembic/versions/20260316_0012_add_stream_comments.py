"""add stream comments table

Revision ID: 20260316_0012
Revises: 20260315_0011
Create Date: 2026-03-16 15:10:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260316_0012"
down_revision: Union[str, None] = "20260315_0011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "stream_comments",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("stream_id", sa.String(length=80), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=True),
        sa.Column("author_name", sa.String(length=120), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["stream_id"], ["stream_sessions.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_stream_comments_stream_id",
        "stream_comments",
        ["stream_id"],
        unique=False,
    )
    op.create_index(
        "ix_stream_comments_user_id",
        "stream_comments",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_stream_comments_created_at",
        "stream_comments",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_stream_comments_created_at", table_name="stream_comments")
    op.drop_index("ix_stream_comments_user_id", table_name="stream_comments")
    op.drop_index("ix_stream_comments_stream_id", table_name="stream_comments")
    op.drop_table("stream_comments")
