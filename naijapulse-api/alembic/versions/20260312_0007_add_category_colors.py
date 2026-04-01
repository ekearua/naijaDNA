"""add category color hex column

Revision ID: 20260312_0007
Revises: 20260311_0006
Create Date: 2026-03-12 10:40:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260312_0007"
down_revision: Union[str, None] = "20260311_0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "categories",
        sa.Column("color_hex", sa.String(length=7), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("categories", "color_hex")
