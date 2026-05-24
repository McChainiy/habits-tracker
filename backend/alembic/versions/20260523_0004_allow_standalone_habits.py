"""allow standalone habits

Revision ID: 20260523_0004
Revises: 20260523_0003
Create Date: 2026-05-23
"""

from __future__ import annotations

from alembic import op

revision = "20260523_0004"
down_revision = "20260523_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("habits", "challenge_id", nullable=True)


def downgrade() -> None:
    op.alter_column("habits", "challenge_id", nullable=False)
