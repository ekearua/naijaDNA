"""add categories table and poll metadata columns

Revision ID: 20260311_0003
Revises: 20260309_0002
Create Date: 2026-03-11 09:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260311_0003"
down_revision: Union[str, None] = "20260309_0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "categories",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_categories_name", "categories", ["name"], unique=True)

    op.add_column("polls", sa.Column("category_id", sa.String(length=80), nullable=True))
    op.add_column("polls", sa.Column("created_by", sa.String(length=128), nullable=True))
    op.create_index("ix_polls_category_id", "polls", ["category_id"], unique=False)
    op.create_index("ix_polls_created_by", "polls", ["created_by"], unique=False)
    op.create_foreign_key(
        "fk_polls_category_id_categories",
        "polls",
        "categories",
        ["category_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_polls_category_id_categories", "polls", type_="foreignkey")
    op.drop_index("ix_polls_created_by", table_name="polls")
    op.drop_index("ix_polls_category_id", table_name="polls")
    op.drop_column("polls", "created_by")
    op.drop_column("polls", "category_id")

    op.drop_index("ix_categories_name", table_name="categories")
    op.drop_table("categories")
