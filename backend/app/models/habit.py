from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.utils import utcnow

if TYPE_CHECKING:
    from app.models.challenge import Challenge
    from app.models.habit_entry import HabitEntry


class Habit(Base):
    __tablename__ = "habits"
    __table_args__ = (
        UniqueConstraint("challenge_id", "sort_order", name="uq_habits_challenge_sort_order"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    challenge_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("challenges.id", ondelete="CASCADE"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    note: Mapped[str] = mapped_column(Text, nullable=False, default="")
    penalty_text: Mapped[str] = mapped_column(Text, nullable=False)
    color_hex: Mapped[str] = mapped_column(String(16), nullable=False)
    schedule_mode: Mapped[str] = mapped_column(String(16), nullable=False, default="days")
    scheduled_weekdays: Mapped[str] = mapped_column(String(32), nullable=False, default="1,2,3,4,5,6,7")
    weekly_target: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    reminder_times: Mapped[str] = mapped_column(Text, nullable=False, default="")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)
    is_archived: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
        index=True,
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    challenge: Mapped[Challenge] = relationship(back_populates="habits")
    entries: Mapped[list[HabitEntry]] = relationship(
        back_populates="habit",
        cascade="all, delete-orphan",
        order_by="HabitEntry.entry_date",
    )
