"""add homepage settings

Revision ID: 20260407_0024
Revises: 20260406_0023
Create Date: 2026-04-07 17:35:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260407_0024"
down_revision: Union[str, Sequence[str], None] = "20260406_0023"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "homepage_settings",
        sa.Column("id", sa.Integer(), autoincrement=False, nullable=False),
        sa.Column("latest_window_hours", sa.Integer(), nullable=False, server_default="6"),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute(
        """
        INSERT INTO homepage_settings (id, latest_window_hours, created_at, updated_at)
        VALUES (1, 6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        """
    )


def downgrade() -> None:
    op.drop_table("homepage_settings")
