"""expand homepage settings

Revision ID: 20260407_0025
Revises: 20260407_0024
Create Date: 2026-04-07 18:05:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260407_0025"
down_revision: Union[str, Sequence[str], None] = "20260407_0024"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "homepage_settings",
        sa.Column("latest_autofill_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        "homepage_settings",
        sa.Column("latest_item_limit", sa.Integer(), nullable=False, server_default="20"),
    )
    op.add_column(
        "homepage_settings",
        sa.Column(
            "latest_fallback_window_hours",
            sa.Integer(),
            nullable=False,
            server_default="24",
        ),
    )


def downgrade() -> None:
    op.drop_column("homepage_settings", "latest_fallback_window_hours")
    op.drop_column("homepage_settings", "latest_item_limit")
    op.drop_column("homepage_settings", "latest_autofill_enabled")
