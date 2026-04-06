"""add admin access request review fields

Revision ID: 20260406_0022
Revises: 20260402_0021
Create Date: 2026-04-06 17:10:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20260406_0022"
down_revision: str | None = "20260402_0021"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "admin_access_requests",
        sa.Column("reviewed_by_user_id", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "admin_access_requests",
        sa.Column("granted_user_id", sa.String(length=128), nullable=True),
    )
    op.add_column(
        "admin_access_requests",
        sa.Column("review_note", sa.Text(), nullable=True),
    )
    op.create_index(
        "ix_admin_access_requests_reviewed_by_user_id",
        "admin_access_requests",
        ["reviewed_by_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_admin_access_requests_granted_user_id",
        "admin_access_requests",
        ["granted_user_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_admin_access_requests_reviewed_by_user_id_users",
        "admin_access_requests",
        "users",
        ["reviewed_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_admin_access_requests_granted_user_id_users",
        "admin_access_requests",
        "users",
        ["granted_user_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_admin_access_requests_granted_user_id_users",
        "admin_access_requests",
        type_="foreignkey",
    )
    op.drop_constraint(
        "fk_admin_access_requests_reviewed_by_user_id_users",
        "admin_access_requests",
        type_="foreignkey",
    )
    op.drop_index(
        "ix_admin_access_requests_granted_user_id",
        table_name="admin_access_requests",
    )
    op.drop_index(
        "ix_admin_access_requests_reviewed_by_user_id",
        table_name="admin_access_requests",
    )
    op.drop_column("admin_access_requests", "review_note")
    op.drop_column("admin_access_requests", "granted_user_id")
    op.drop_column("admin_access_requests", "reviewed_by_user_id")
