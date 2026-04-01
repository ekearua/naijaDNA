"""add poll votes table for idempotent replay

Revision ID: 20260309_0002
Revises: 20260305_0001
Create Date: 2026-03-09 10:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "20260309_0002"
down_revision: Union[str, None] = "20260305_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "poll_votes",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("poll_id", sa.String(length=80), nullable=False),
        sa.Column("option_id", sa.String(length=80), nullable=False),
        sa.Column("voter_id", sa.String(length=128), nullable=True),
        sa.Column("idempotency_key", sa.String(length=160), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=False), nullable=False),
        sa.ForeignKeyConstraint(["poll_id"], ["polls.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("idempotency_key", name="uq_poll_vote_idempotency_key"),
        sa.UniqueConstraint("poll_id", "voter_id", name="uq_poll_vote_per_voter"),
    )
    op.create_index("ix_poll_votes_poll_id", "poll_votes", ["poll_id"], unique=False)
    op.create_index("ix_poll_votes_voter_id", "poll_votes", ["voter_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_poll_votes_voter_id", table_name="poll_votes")
    op.drop_index("ix_poll_votes_poll_id", table_name="poll_votes")
    op.drop_table("poll_votes")
