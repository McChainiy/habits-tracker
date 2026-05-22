"""initial habit tracker schema

Revision ID: 20260522_0001
Revises:
Create Date: 2026-05-22
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20260522_0001"
down_revision = None
branch_labels = None
depends_on = None

challenge_status = postgresql.ENUM(
    "draft",
    "active",
    "completed",
    name="challenge_status",
    create_type=False,
)
habit_entry_status = postgresql.ENUM(
    "done",
    "failed",
    "skipped",
    name="habit_entry_status",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    challenge_status.create(bind, checkfirst=True)
    habit_entry_status.create(bind, checkfirst=True)

    op.create_table(
        "challenges",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("month", sa.Integer(), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("status", challenge_status, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("month >= 1 AND month <= 12", name="ck_challenges_month"),
        sa.CheckConstraint("end_date >= start_date", name="ck_challenges_date_range"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "habits",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("challenge_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("note", sa.Text(), nullable=False),
        sa.Column("penalty_text", sa.Text(), nullable=False),
        sa.Column("color_hex", sa.String(length=16), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_archived", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["challenge_id"], ["challenges.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("challenge_id", "sort_order", name="uq_habits_challenge_sort_order"),
    )

    op.create_table(
        "habit_entries",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("habit_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("entry_date", sa.Date(), nullable=False),
        sa.Column("status", habit_entry_status, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["habit_id"], ["habits.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("habit_id", "entry_date", name="uq_habit_entries_habit_date"),
    )


def downgrade() -> None:
    op.drop_table("habit_entries")
    op.drop_table("habits")
    op.drop_table("challenges")
    habit_entry_status.drop(op.get_bind(), checkfirst=True)
    challenge_status.drop(op.get_bind(), checkfirst=True)
