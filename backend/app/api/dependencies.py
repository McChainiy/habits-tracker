from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.user import User


async def get_current_user(
    x_user_id: Annotated[uuid.UUID | None, Header(alias="X-User-Id")] = None,
    session: AsyncSession = Depends(get_session),
) -> User:
    if x_user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="X-User-Id header is required",
        )

    result = await session.execute(
        select(User).where(User.id == x_user_id, User.deleted_at.is_(None))
    )
    user = result.scalars().first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
