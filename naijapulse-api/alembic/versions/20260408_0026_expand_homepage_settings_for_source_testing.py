"""expand homepage settings for source testing

Revision ID: 20260408_0026
Revises: 20260407_0025
Create Date: 2026-04-08 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260408_0026"
down_revision = "20260407_0025"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "homepage_settings",
        sa.Column(
            "direct_gnews_top_publish_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "homepage_settings",
        sa.Column(
            "category_autofill_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "homepage_settings",
        sa.Column(
            "category_window_hours",
            sa.Integer(),
            nullable=False,
            server_default="12",
        ),
    )
    op.alter_column("homepage_settings", "direct_gnews_top_publish_enabled", server_default=None)
    op.alter_column("homepage_settings", "category_autofill_enabled", server_default=None)
    op.alter_column("homepage_settings", "category_window_hours", server_default=None)


def downgrade() -> None:
    op.drop_column("homepage_settings", "category_window_hours")
    op.drop_column("homepage_settings", "category_autofill_enabled")
    op.drop_column("homepage_settings", "direct_gnews_top_publish_enabled")
