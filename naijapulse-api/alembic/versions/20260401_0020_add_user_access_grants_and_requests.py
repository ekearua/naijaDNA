"""add user access grants and requests

Revision ID: 20260401_0020
Revises: 20260401_0019
Create Date: 2026-04-01 18:10:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260401_0020"
down_revision: str | None = "20260401_0019"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "stream_access_granted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "stream_hosting_granted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "contribution_access_granted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    op.create_table(
        "user_access_requests",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("access_type", sa.String(length=32), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=16),
            nullable=False,
            server_default="pending",
        ),
        sa.Column("reviewed_by_user_id", sa.String(length=128), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["reviewed_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_user_access_requests_user_id",
        "user_access_requests",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_access_requests_access_type",
        "user_access_requests",
        ["access_type"],
        unique=False,
    )
    op.create_index(
        "ix_user_access_requests_status",
        "user_access_requests",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_user_access_requests_reviewed_by_user_id",
        "user_access_requests",
        ["reviewed_by_user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_user_access_requests_reviewed_by_user_id",
        table_name="user_access_requests",
    )
    op.drop_index("ix_user_access_requests_status", table_name="user_access_requests")
    op.drop_index(
        "ix_user_access_requests_access_type",
        table_name="user_access_requests",
    )
    op.drop_index("ix_user_access_requests_user_id", table_name="user_access_requests")
    op.drop_table("user_access_requests")

    op.drop_column("users", "contribution_access_granted")
    op.drop_column("users", "stream_hosting_granted")
    op.drop_column("users", "stream_access_granted")
