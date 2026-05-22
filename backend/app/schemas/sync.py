from __future__ import annotations

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class SyncChallenge(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2024, le=2100)
    start_date: date
    end_date: date
    status: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None


class SyncHabit(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    challenge_id: uuid.UUID
    title: str = Field(min_length=1, max_length=120)
    note: str = ""
    penalty_text: str = Field(min_length=1)
    color_hex: str = Field(default="#62766A", min_length=4, max_length=16)
    sort_order: int
    is_archived: bool = False
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None


class SyncHabitEntry(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    habit_id: uuid.UUID
    entry_date: date
    status: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None


class SyncPushRequest(BaseModel):
    challenges: list[SyncChallenge] = []
    habits: list[SyncHabit] = []
    habit_entries: list[SyncHabitEntry] = []


class SyncChangesResponse(BaseModel):
    server_timestamp: datetime
    challenges: list[SyncChallenge]
    habits: list[SyncHabit]
    habit_entries: list[SyncHabitEntry]
