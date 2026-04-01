"""add stream session and viewer presence tables

Revision ID: 20260315_0010
Revises: 20260313_0009
Create Date: 2026-03-15 09:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260315_0010"
down_revision: Union[str, None] = "20260313_0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "stream_sessions",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("host_user_id", sa.String(length=128), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(length=120), nullable=False),
        sa.Column("cover_image_url", sa.Text(), nullable=True),
        sa.Column("stream_url", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("scheduled_for", sa.DateTime(timezone=False), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=False), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["host_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_stream_sessions_host_user_id",
        "stream_sessions",
        ["host_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_stream_sessions_category",
        "stream_sessions",
        ["category"],
        unique=False,
    )
    op.create_index(
        "ix_stream_sessions_status",
        "stream_sessions",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_stream_sessions_scheduled_for",
        "stream_sessions",
        ["scheduled_for"],
        unique=False,
    )
    op.create_index(
        "ix_stream_sessions_started_at",
        "stream_sessions",
        ["started_at"],
        unique=False,
    )
    op.create_index(
        "ix_stream_sessions_ended_at",
        "stream_sessions",
        ["ended_at"],
        unique=False,
    )

    op.create_table(
        "stream_viewer_presence",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("stream_id", sa.String(length=80), nullable=False),
        sa.Column("viewer_key", sa.String(length=128), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=True),
        sa.Column("joined_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("left_at", sa.DateTime(timezone=False), nullable=True),
        sa.ForeignKeyConstraint(["stream_id"], ["stream_sessions.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("stream_id", "viewer_key", name="uq_stream_viewer_presence"),
    )
    op.create_index(
        "ix_stream_viewer_presence_stream_id",
        "stream_viewer_presence",
        ["stream_id"],
        unique=False,
    )
    op.create_index(
        "ix_stream_viewer_presence_viewer_key",
        "stream_viewer_presence",
        ["viewer_key"],
        unique=False,
    )
    op.create_index(
        "ix_stream_viewer_presence_user_id",
        "stream_viewer_presence",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_stream_viewer_presence_last_seen_at",
        "stream_viewer_presence",
        ["last_seen_at"],
        unique=False,
    )
    op.create_index(
        "ix_stream_viewer_presence_left_at",
        "stream_viewer_presence",
        ["left_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_stream_viewer_presence_left_at",
        table_name="stream_viewer_presence",
    )
    op.drop_index(
        "ix_stream_viewer_presence_last_seen_at",
        table_name="stream_viewer_presence",
    )
    op.drop_index(
        "ix_stream_viewer_presence_user_id",
        table_name="stream_viewer_presence",
    )
    op.drop_index(
        "ix_stream_viewer_presence_viewer_key",
        table_name="stream_viewer_presence",
    )
    op.drop_index(
        "ix_stream_viewer_presence_stream_id",
        table_name="stream_viewer_presence",
    )
    op.drop_table("stream_viewer_presence")

    op.drop_index("ix_stream_sessions_ended_at", table_name="stream_sessions")
    op.drop_index("ix_stream_sessions_started_at", table_name="stream_sessions")
    op.drop_index("ix_stream_sessions_scheduled_for", table_name="stream_sessions")
    op.drop_index("ix_stream_sessions_status", table_name="stream_sessions")
    op.drop_index("ix_stream_sessions_category", table_name="stream_sessions")
    op.drop_index("ix_stream_sessions_host_user_id", table_name="stream_sessions")
    op.drop_table("stream_sessions")
