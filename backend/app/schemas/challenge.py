from __future__ import annotations

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class HabitCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    note: str = ""
    penalty_text: str = Field(min_length=1)
    color_hex: str = Field(default="#62766A", min_length=4, max_length=16)


class ChallengeCreate(BaseModel):
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2024, le=2100)
    habits: list[HabitCreate] = Field(min_length=1, max_length=5)


class HabitEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    entry_date: date
    status: str
    created_at: datetime
    updated_at: datetime


class HabitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    note: str
    penalty_text: str
    color_hex: str
    sort_order: int
    is_archived: bool
    created_at: datetime
    entries: list[HabitEntryRead] = []


class ChallengeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    month: int
    year: int
    start_date: date
    end_date: date
    status: str
    created_at: datetime
    habits: list[HabitRead] = []
