from __future__ import annotations

import calendar
import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import get_current_user
from app.db.session import get_session
from app.models.challenge import Challenge, ChallengeStatus
from app.models.habit import Habit
from app.models.user import User
from app.schemas.challenge import ChallengeCreate, ChallengeRead

router = APIRouter(prefix="/challenges", tags=["challenges"])


@router.get("", response_model=list[ChallengeRead])
async def list_challenges(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ChallengeRead]:
    result = await session.execute(
        select(Challenge)
        .where(Challenge.user_id == user.id, Challenge.deleted_at.is_(None))
        .options(selectinload(Challenge.habits).selectinload(Habit.entries))
        .order_by(Challenge.updated_at.desc())
    )
    return [ChallengeRead.model_validate(challenge) for challenge in result.scalars().unique()]


@router.get("/{challenge_id}", response_model=ChallengeRead)
async def get_challenge(
    challenge_id: uuid.UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ChallengeRead:
    challenge = await load_challenge(session, user.id, challenge_id)
    return ChallengeRead.model_validate(challenge)


@router.post("", response_model=ChallengeRead, status_code=status.HTTP_201_CREATED)
async def create_challenge(
    payload: ChallengeCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ChallengeRead:
    start_date = date(payload.year, payload.month, 1)
    last_day = calendar.monthrange(payload.year, payload.month)[1]
    end_date = date(payload.year, payload.month, last_day)

    challenge = Challenge(
        user_id=user.id,
        month=payload.month,
        year=payload.year,
        start_date=start_date,
        end_date=end_date,
        status=ChallengeStatus.ACTIVE,
    )

    for index, item in enumerate(payload.habits):
        challenge.habits.append(
            Habit(
                user_id=user.id,
                title=item.title,
                note=item.note,
                penalty_text=item.penalty_text,
                color_hex=item.color_hex,
                sort_order=index,
            )
        )

    session.add(challenge)
    await session.commit()
    created_challenge = await load_challenge(session, user.id, challenge.id)
    return ChallengeRead.model_validate(created_challenge)


async def load_challenge(
    session: AsyncSession,
    user_id: uuid.UUID,
    challenge_id: uuid.UUID,
) -> Challenge:
    result = await session.execute(
        select(Challenge)
        .where(
            Challenge.id == challenge_id,
            Challenge.user_id == user_id,
            Challenge.deleted_at.is_(None),
        )
        .options(selectinload(Challenge.habits).selectinload(Habit.entries))
    )
    challenge = result.scalars().first()
    if challenge is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Challenge not found")
    return challenge
