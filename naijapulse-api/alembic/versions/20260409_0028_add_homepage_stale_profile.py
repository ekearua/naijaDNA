"""add homepage stale profile

Revision ID: 20260409_0028
Revises: 20260408_0027
Create Date: 2026-04-09 10:15:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260409_0028"
down_revision = "20260408_0027"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "homepage_settings",
        sa.Column(
            "stale_content_profile",
            sa.String(length=32),
            nullable=False,
            server_default="balanced",
        ),
    )
    op.alter_column("homepage_settings", "stale_content_profile", server_default=None)


def downgrade() -> None:
    op.drop_column("homepage_settings", "stale_content_profile")
