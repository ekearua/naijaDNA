"""add admin access requests table

Revision ID: 20260331_0016
Revises: 20260330_0015
Create Date: 2026-03-31 14:35:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260331_0016"
down_revision: str | None = "20260330_0015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "admin_access_requests",
        sa.Column("id", sa.String(length=128), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("work_email", sa.String(length=255), nullable=False),
        sa.Column("requested_role", sa.String(length=120), nullable=False),
        sa.Column("bureau", sa.String(length=120), nullable=True),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_admin_access_requests_work_email",
        "admin_access_requests",
        ["work_email"],
        unique=False,
    )
    op.create_index(
        "ix_admin_access_requests_status",
        "admin_access_requests",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_admin_access_requests_status", table_name="admin_access_requests")
    op.drop_index("ix_admin_access_requests_work_email", table_name="admin_access_requests")
    op.drop_table("admin_access_requests")
