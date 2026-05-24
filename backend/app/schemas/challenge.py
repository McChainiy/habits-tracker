from __future__ import annotations

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class HabitCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    note: str = ""
    penalty_text: str = ""
    color_hex: str = Field(default="#62766A", min_length=4, max_length=16)
    schedule_mode: str = Field(default="days", max_length=16)
    scheduled_weekdays: str = Field(default="1,2,3,4,5,6,7", max_length=32)
    weekly_target: int = Field(default=3, ge=1, le=7)
    reminder_times: str = ""


class ChallengeCreate(BaseModel):
    custom_title: str = Field(default="", max_length=120)
    color_hex: str = Field(default="#62766A", min_length=4, max_length=16)
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2024, le=2100)
    duration_weeks: int = Field(default=4, ge=1, le=100)
    target_weeks: int = Field(default=3, ge=1, le=100)
    is_timeless: bool = False
    reward_text: str = ""
    habits: list[HabitCreate] = Field(min_length=1, max_length=5)


class HabitEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    entry_date: date
    status: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None


class HabitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    challenge_id: uuid.UUID | None
    title: str
    note: str
    penalty_text: str
    color_hex: str
    schedule_mode: str
    scheduled_weekdays: str
    weekly_target: int
    reminder_times: str
    sort_order: int
    is_archived: bool
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    entries: list[HabitEntryRead] = []


class ChallengeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    custom_title: str
    color_hex: str
    month: int
    year: int
    start_date: date
    end_date: date
    duration_weeks: int
    target_weeks: int
    is_timeless: bool
    reward_text: str
    status: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    habits: list[HabitRead] = []
