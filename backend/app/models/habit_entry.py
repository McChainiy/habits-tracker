from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, Enum, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.habit import Habit


class HabitEntryStatus(StrEnum):
    DONE = "done"
    FAILED = "failed"
    SKIPPED = "skipped"


class HabitEntry(Base):
    __tablename__ = "habit_entries"
    __table_args__ = (
        UniqueConstraint("habit_id", "entry_date", name="uq_habit_entries_habit_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    habit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("habits.id", ondelete="CASCADE"),
        nullable=False,
    )
    entry_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[HabitEntryStatus] = mapped_column(
        Enum(
            HabitEntryStatus,
            name="habit_entry_status",
            values_callable=lambda enum_cls: [item.value for item in enum_cls],
        ),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    habit: Mapped[Habit] = relationship(back_populates="entries")
