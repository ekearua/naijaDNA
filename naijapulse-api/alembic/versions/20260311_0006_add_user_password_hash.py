"""add user password hash column for auth flows

Revision ID: 20260311_0006
Revises: 20260311_0005
Create Date: 2026-03-11 18:20:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260311_0006"
down_revision: Union[str, None] = "20260311_0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(length=512), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "password_hash")
