from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    email: str | None = Field(default=None, max_length=320)
    display_name: str = Field(default="", max_length=120)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None
    display_name: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
