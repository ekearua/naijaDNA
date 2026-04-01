"""add feed_tags table for homepage trust tag strip

Revision ID: 20260313_0009
Revises: 20260313_0008
Create Date: 2026-03-13 13:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260313_0009"
down_revision: Union[str, None] = "20260313_0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "feed_tags",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("color_hex", sa.String(length=7), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    op.create_index("ix_feed_tags_name", "feed_tags", ["name"], unique=True)
    op.create_index("ix_feed_tags_position", "feed_tags", ["position"], unique=False)
    op.create_index("ix_feed_tags_is_active", "feed_tags", ["is_active"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_feed_tags_is_active", table_name="feed_tags")
    op.drop_index("ix_feed_tags_position", table_name="feed_tags")
    op.drop_index("ix_feed_tags_name", table_name="feed_tags")
    op.drop_table("feed_tags")
