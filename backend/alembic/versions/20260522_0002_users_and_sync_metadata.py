"""add users and sync metadata

Revision ID: 20260522_0002
Revises: 20260522_0001
Create Date: 2026-05-22
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "20260522_0002"
down_revision = "20260522_0001"
branch_labels = None
depends_on = None

DEFAULT_USER_ID = "00000000-0000-0000-0000-000000000001"


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=True),
        sa.Column("display_name", sa.String(length=120), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )

    op.execute(
        f"""
        INSERT INTO users (id, email, display_name, created_at, updated_at)
        VALUES ('{DEFAULT_USER_ID}'::uuid, NULL, 'Local user', now(), now())
        ON CONFLICT (id) DO NOTHING
        """
    )

    op.add_column("challenges", sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("challenges", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("challenges", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.execute(
        f"""
        UPDATE challenges
        SET user_id = '{DEFAULT_USER_ID}'::uuid,
            updated_at = COALESCE(created_at, now())
        WHERE user_id IS NULL
        """
    )
    op.alter_column("challenges", "user_id", nullable=False)
    op.alter_column("challenges", "updated_at", nullable=False)
    op.create_index("ix_challenges_user_id", "challenges", ["user_id"])
    op.create_index("ix_challenges_updated_at", "challenges", ["updated_at"])
    op.create_foreign_key(
        "fk_challenges_user_id_users",
        "challenges",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )

    op.add_column("habits", sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("habits", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("habits", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.execute(
        """
        UPDATE habits
        SET user_id = challenges.user_id,
            updated_at = COALESCE(habits.created_at, now())
        FROM challenges
        WHERE habits.challenge_id = challenges.id
          AND habits.user_id IS NULL
        """
    )
    op.alter_column("habits", "user_id", nullable=False)
    op.alter_column("habits", "updated_at", nullable=False)
    op.create_index("ix_habits_user_id", "habits", ["user_id"])
    op.create_index("ix_habits_updated_at", "habits", ["updated_at"])
    op.create_foreign_key(
        "fk_habits_user_id_users",
        "habits",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )

    op.add_column(
        "habit_entries",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.add_column(
        "habit_entries",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.execute(
        """
        UPDATE habit_entries
        SET user_id = habits.user_id
        FROM habits
        WHERE habit_entries.habit_id = habits.id
          AND habit_entries.user_id IS NULL
        """
    )
    op.alter_column("habit_entries", "user_id", nullable=False)
    op.create_index("ix_habit_entries_user_id", "habit_entries", ["user_id"])
    op.create_index("ix_habit_entries_updated_at", "habit_entries", ["updated_at"])
    op.create_foreign_key(
        "fk_habit_entries_user_id_users",
        "habit_entries",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint("fk_habit_entries_user_id_users", "habit_entries", type_="foreignkey")
    op.drop_index("ix_habit_entries_updated_at", table_name="habit_entries")
    op.drop_index("ix_habit_entries_user_id", table_name="habit_entries")
    op.drop_column("habit_entries", "deleted_at")
    op.drop_column("habit_entries", "user_id")

    op.drop_constraint("fk_habits_user_id_users", "habits", type_="foreignkey")
    op.drop_index("ix_habits_updated_at", table_name="habits")
    op.drop_index("ix_habits_user_id", table_name="habits")
    op.drop_column("habits", "deleted_at")
    op.drop_column("habits", "updated_at")
    op.drop_column("habits", "user_id")

    op.drop_constraint("fk_challenges_user_id_users", "challenges", type_="foreignkey")
    op.drop_index("ix_challenges_updated_at", table_name="challenges")
    op.drop_index("ix_challenges_user_id", table_name="challenges")
    op.drop_column("challenges", "deleted_at")
    op.drop_column("challenges", "updated_at")
    op.drop_column("challenges", "user_id")

    op.drop_table("users")
