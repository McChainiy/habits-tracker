"""add challenge and habit planning fields

Revision ID: 20260523_0003
Revises: 20260522_0002
Create Date: 2026-05-23
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260523_0003"
down_revision = "20260522_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "challenges",
        sa.Column("custom_title", sa.String(length=120), server_default="", nullable=False),
    )
    op.add_column(
        "challenges",
        sa.Column("color_hex", sa.String(length=16), server_default="#62766A", nullable=False),
    )
    op.add_column(
        "challenges",
        sa.Column("duration_weeks", sa.Integer(), server_default="4", nullable=False),
    )
    op.add_column(
        "challenges",
        sa.Column("target_weeks", sa.Integer(), server_default="3", nullable=False),
    )
    op.add_column(
        "challenges",
        sa.Column("is_timeless", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "challenges",
        sa.Column("reward_text", sa.Text(), server_default="", nullable=False),
    )

    op.add_column(
        "habits",
        sa.Column("schedule_mode", sa.String(length=16), server_default="days", nullable=False),
    )
    op.add_column(
        "habits",
        sa.Column(
            "scheduled_weekdays",
            sa.String(length=32),
            server_default="1,2,3,4,5,6,7",
            nullable=False,
        ),
    )
    op.add_column(
        "habits",
        sa.Column("weekly_target", sa.Integer(), server_default="3", nullable=False),
    )
    op.add_column(
        "habits",
        sa.Column("reminder_times", sa.Text(), server_default="", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("habits", "reminder_times")
    op.drop_column("habits", "weekly_target")
    op.drop_column("habits", "scheduled_weekdays")
    op.drop_column("habits", "schedule_mode")

    op.drop_column("challenges", "reward_text")
    op.drop_column("challenges", "is_timeless")
    op.drop_column("challenges", "target_weeks")
    op.drop_column("challenges", "duration_weeks")
    op.drop_column("challenges", "color_hex")
    op.drop_column("challenges", "custom_title")
