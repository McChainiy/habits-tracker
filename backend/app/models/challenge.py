from __future__ import annotations

import uuid
from datetime import date, datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, Date, DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.utils import utcnow

if TYPE_CHECKING:
    from app.models.habit import Habit
    from app.models.user import User


class ChallengeStatus(StrEnum):
    DRAFT = "draft"
    ACTIVE = "active"
    COMPLETED = "completed"


class Challenge(Base):
    __tablename__ = "challenges"
    __table_args__ = (
        CheckConstraint("month >= 1 AND month <= 12", name="ck_challenges_month"),
        CheckConstraint("end_date >= start_date", name="ck_challenges_date_range"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    custom_title: Mapped[str] = mapped_column(String(120), nullable=False, default="")
    color_hex: Mapped[str] = mapped_column(String(16), nullable=False, default="#62766A")
    month: Mapped[int] = mapped_column(Integer, nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    duration_weeks: Mapped[int] = mapped_column(Integer, nullable=False, default=4)
    target_weeks: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    is_timeless: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    reward_text: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status: Mapped[ChallengeStatus] = mapped_column(
        Enum(
            ChallengeStatus,
            name="challenge_status",
            values_callable=lambda enum_cls: [item.value for item in enum_cls],
        ),
        nullable=False,
        default=ChallengeStatus.DRAFT,
    )
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

    user: Mapped[User] = relationship(back_populates="challenges")
    habits: Mapped[list[Habit]] = relationship(
        back_populates="challenge",
        cascade="all, delete-orphan",
        order_by="Habit.sort_order",
    )
