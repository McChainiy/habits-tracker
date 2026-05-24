"""add updated_at triggers

Revision ID: 20260524_0005
Revises: 20260523_0004
Create Date: 2026-05-24
"""

from __future__ import annotations

from alembic import op

revision = "20260524_0005"
down_revision = "20260523_0004"
branch_labels = None
depends_on = None

TABLES = ("users", "challenges", "habits", "habit_entries")


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION set_updated_at()
        RETURNS trigger AS $$
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )

    for table in TABLES:
        op.execute(f"DROP TRIGGER IF EXISTS trg_{table}_set_updated_at ON {table};")
        op.execute(
            f"""
            CREATE TRIGGER trg_{table}_set_updated_at
            BEFORE UPDATE ON {table}
            FOR EACH ROW
            EXECUTE FUNCTION set_updated_at();
            """
        )
        op.execute(f"UPDATE {table} SET updated_at = now();")


def downgrade() -> None:
    for table in TABLES:
        op.execute(f"DROP TRIGGER IF EXISTS trg_{table}_set_updated_at ON {table};")

    op.execute("DROP FUNCTION IF EXISTS set_updated_at();")
