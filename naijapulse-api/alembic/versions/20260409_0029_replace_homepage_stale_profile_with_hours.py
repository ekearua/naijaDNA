"""replace homepage stale profile with exact hour thresholds

Revision ID: 20260409_0029
Revises: 20260409_0028
Create Date: 2026-04-09 11:05:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260409_0029"
down_revision = "20260409_0028"
branch_labels = None
depends_on = None


def upgrade() -> None:
    columns = [
        ("stale_general_hours", 36),
        ("stale_world_hours", 48),
        ("stale_business_hours", 48),
        ("stale_technology_hours", 72),
        ("stale_entertainment_hours", 72),
        ("stale_science_hours", 72),
        ("stale_sports_hours", 30),
        ("stale_health_hours", 72),
        ("stale_breaking_hours", 18),
        ("stale_opinion_hours", 168),
    ]
    for name, default in columns:
        op.add_column(
            "homepage_settings",
            sa.Column(name, sa.Integer(), nullable=False, server_default=str(default)),
        )

    op.execute(
        """
        UPDATE homepage_settings
        SET
            stale_general_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 24
                WHEN 'extended' THEN 48
                ELSE 36
            END,
            stale_world_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 24
                WHEN 'extended' THEN 72
                ELSE 48
            END,
            stale_business_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 24
                WHEN 'extended' THEN 72
                ELSE 48
            END,
            stale_technology_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 48
                WHEN 'extended' THEN 96
                ELSE 72
            END,
            stale_entertainment_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 48
                WHEN 'extended' THEN 96
                ELSE 72
            END,
            stale_science_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 48
                WHEN 'extended' THEN 96
                ELSE 72
            END,
            stale_sports_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 18
                WHEN 'extended' THEN 48
                ELSE 30
            END,
            stale_health_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 48
                WHEN 'extended' THEN 96
                ELSE 72
            END,
            stale_breaking_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 12
                WHEN 'extended' THEN 24
                ELSE 18
            END,
            stale_opinion_hours = CASE stale_content_profile
                WHEN 'aggressive' THEN 120
                WHEN 'extended' THEN 240
                ELSE 168
            END
        """
    )

    for name, _ in columns:
        op.alter_column("homepage_settings", name, server_default=None)

    op.drop_column("homepage_settings", "stale_content_profile")


def downgrade() -> None:
    op.add_column(
        "homepage_settings",
        sa.Column(
            "stale_content_profile",
            sa.String(length=32),
            nullable=False,
            server_default="balanced",
        ),
    )
    op.execute("UPDATE homepage_settings SET stale_content_profile = 'balanced'")
    op.alter_column("homepage_settings", "stale_content_profile", server_default=None)

    for name in [
        "stale_general_hours",
        "stale_world_hours",
        "stale_business_hours",
        "stale_technology_hours",
        "stale_entertainment_hours",
        "stale_science_hours",
        "stale_sports_hours",
        "stale_health_hours",
        "stale_breaking_hours",
        "stale_opinion_hours",
    ]:
        op.drop_column("homepage_settings", name)
