from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, DateTime, Enum, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.habit import Habit


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
    month: Mapped[int] = mapped_column(Integer, nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
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
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    habits: Mapped[list[Habit]] = relationship(
        back_populates="challenge",
        cascade="all, delete-orphan",
        order_by="Habit.sort_order",
    )
