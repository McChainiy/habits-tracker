from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user
from app.db.session import get_session
from app.models.challenge import Challenge, ChallengeStatus
from app.models.habit import Habit
from app.models.habit_entry import HabitEntry, HabitEntryStatus
from app.models.user import User
from app.models.utils import utcnow
from app.schemas.sync import (
    SyncChallenge,
    SyncChangesResponse,
    SyncHabit,
    SyncHabitEntry,
    SyncPushRequest,
)

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/changes", response_model=SyncChangesResponse)
async def pull_changes(
    since: datetime | None = Query(default=None),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> SyncChangesResponse:
    since_value = normalize_since(since)

    challenges = await changed_challenges(session, user.id, since_value)
    habits = await changed_habits(session, user.id, since_value)
    habit_entries = await changed_habit_entries(session, user.id, since_value)

    return SyncChangesResponse(
        server_timestamp=utcnow(),
        challenges=[SyncChallenge.model_validate(item) for item in challenges],
        habits=[SyncHabit.model_validate(item) for item in habits],
        habit_entries=[SyncHabitEntry.model_validate(item) for item in habit_entries],
    )


@router.post("/push", response_model=SyncChangesResponse)
async def push_changes(
    payload: SyncPushRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> SyncChangesResponse:
    changed_challenge_ids: set[uuid.UUID] = set()
    changed_habit_ids: set[uuid.UUID] = set()
    changed_entry_ids: set[uuid.UUID] = set()

    for item in payload.challenges:
        changed_challenge_ids.add(await upsert_challenge(session, user.id, item))

    await session.flush()

    for item in payload.habits:
        changed_habit_ids.add(await upsert_habit(session, user.id, item))

    await session.flush()

    for item in payload.habit_entries:
        changed_entry_id = await upsert_habit_entry(session, user.id, item)
        if changed_entry_id is not None:
            changed_entry_ids.add(changed_entry_id)

    await session.commit()

    return SyncChangesResponse(
        server_timestamp=utcnow(),
        challenges=[
            SyncChallenge.model_validate(item)
            for item in await load_challenges_by_ids(session, user.id, changed_challenge_ids)
        ],
        habits=[
            SyncHabit.model_validate(item)
            for item in await load_habits_by_ids(session, user.id, changed_habit_ids)
        ],
        habit_entries=[
            SyncHabitEntry.model_validate(item)
            for item in await load_habit_entries_by_ids(session, user.id, changed_entry_ids)
        ],
    )


def normalize_since(value: datetime | None) -> datetime:
    if value is None:
        return datetime.min.replace(tzinfo=timezone.utc)
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


async def changed_challenges(
    session: AsyncSession,
    user_id: uuid.UUID,
    since: datetime,
) -> list[Challenge]:
    result = await session.execute(
        select(Challenge)
        .where(Challenge.user_id == user_id, Challenge.updated_at > since)
        .order_by(Challenge.updated_at)
    )
    return list(result.scalars())


async def changed_habits(session: AsyncSession, user_id: uuid.UUID, since: datetime) -> list[Habit]:
    result = await session.execute(
        select(Habit)
        .where(Habit.user_id == user_id, Habit.updated_at > since)
        .order_by(Habit.updated_at)
    )
    return list(result.scalars())


async def changed_habit_entries(
    session: AsyncSession,
    user_id: uuid.UUID,
    since: datetime,
) -> list[HabitEntry]:
    result = await session.execute(
        select(HabitEntry)
        .where(HabitEntry.user_id == user_id, HabitEntry.updated_at > since)
        .order_by(HabitEntry.updated_at)
    )
    return list(result.scalars())


async def upsert_challenge(
    session: AsyncSession,
    user_id: uuid.UUID,
    item: SyncChallenge,
) -> uuid.UUID:
    challenge = await session.get(Challenge, item.id)
    now = utcnow()

    if challenge is not None and challenge.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Challenge belongs to another user",
        )

    if challenge is None:
        challenge = Challenge(
            id=item.id,
            user_id=user_id,
            custom_title=item.custom_title,
            color_hex=item.color_hex,
            month=item.month,
            year=item.year,
            start_date=item.start_date,
            end_date=item.end_date,
            duration_weeks=item.duration_weeks,
            target_weeks=item.target_weeks,
            is_timeless=item.is_timeless,
            reward_text=item.reward_text,
            status=parse_challenge_status(item.status),
            created_at=item.created_at,
        )
        session.add(challenge)
    else:
        challenge.custom_title = item.custom_title
        challenge.color_hex = item.color_hex
        challenge.month = item.month
        challenge.year = item.year
        challenge.start_date = item.start_date
        challenge.end_date = item.end_date
        challenge.duration_weeks = item.duration_weeks
        challenge.target_weeks = item.target_weeks
        challenge.is_timeless = item.is_timeless
        challenge.reward_text = item.reward_text
        challenge.status = parse_challenge_status(item.status)

    challenge.updated_at = now
    challenge.deleted_at = item.deleted_at
    return challenge.id


async def upsert_habit(session: AsyncSession, user_id: uuid.UUID, item: SyncHabit) -> uuid.UUID:
    challenge_id = item.challenge_id
    if item.challenge_id is not None:
        challenge = await session.get(Challenge, item.challenge_id)
        if challenge is not None and challenge.user_id != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Challenge belongs to another user")
        if challenge is None:
            challenge_id = None

    habit = await session.get(Habit, item.id)
    now = utcnow()

    if habit is not None and habit.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Habit belongs to another user",
        )

    if habit is None:
        habit = Habit(
            id=item.id,
            user_id=user_id,
            challenge_id=challenge_id,
            title=item.title,
            note=item.note,
            penalty_text=item.penalty_text,
            color_hex=item.color_hex,
            schedule_mode=item.schedule_mode,
            scheduled_weekdays=item.scheduled_weekdays,
            weekly_target=item.weekly_target,
            reminder_times=item.reminder_times,
            sort_order=item.sort_order,
            is_archived=item.is_archived,
            created_at=item.created_at,
        )
        session.add(habit)
    else:
        habit.challenge_id = challenge_id
        habit.title = item.title
        habit.note = item.note
        habit.penalty_text = item.penalty_text
        habit.color_hex = item.color_hex
        habit.schedule_mode = item.schedule_mode
        habit.scheduled_weekdays = item.scheduled_weekdays
        habit.weekly_target = item.weekly_target
        habit.reminder_times = item.reminder_times
        habit.sort_order = item.sort_order
        habit.is_archived = item.is_archived

    habit.updated_at = now
    habit.deleted_at = item.deleted_at
    return habit.id


async def upsert_habit_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    item: SyncHabitEntry,
) -> uuid.UUID | None:
    habit = await session.get(Habit, item.habit_id)
    if habit is None:
        return None
    if habit.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Habit belongs to another user")

    entry = await session.get(HabitEntry, item.id)
    now = utcnow()

    if entry is not None and entry.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Entry belongs to another user",
        )

    if entry is None:
        entry = HabitEntry(
            id=item.id,
            user_id=user_id,
            habit_id=item.habit_id,
            entry_date=item.entry_date,
            status=parse_entry_status(item.status),
            created_at=item.created_at,
        )
        session.add(entry)
    else:
        entry.habit_id = item.habit_id
        entry.entry_date = item.entry_date
        entry.status = parse_entry_status(item.status)

    entry.updated_at = now
    entry.deleted_at = item.deleted_at
    return entry.id


async def load_challenges_by_ids(
    session: AsyncSession,
    user_id: uuid.UUID,
    ids: set[uuid.UUID],
) -> list[Challenge]:
    if not ids:
        return []
    result = await session.execute(
        select(Challenge).where(Challenge.user_id == user_id, Challenge.id.in_(ids))
    )
    return list(result.scalars())


async def load_habits_by_ids(
    session: AsyncSession,
    user_id: uuid.UUID,
    ids: set[uuid.UUID],
) -> list[Habit]:
    if not ids:
        return []
    result = await session.execute(select(Habit).where(Habit.user_id == user_id, Habit.id.in_(ids)))
    return list(result.scalars())


async def load_habit_entries_by_ids(
    session: AsyncSession,
    user_id: uuid.UUID,
    ids: set[uuid.UUID],
) -> list[HabitEntry]:
    if not ids:
        return []
    result = await session.execute(
        select(HabitEntry).where(HabitEntry.user_id == user_id, HabitEntry.id.in_(ids))
    )
    return list(result.scalars())


def parse_challenge_status(value: str) -> ChallengeStatus:
    try:
        return ChallengeStatus(value)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid challenge status",
        ) from exc


def parse_entry_status(value: str) -> HabitEntryStatus:
    try:
        return HabitEntryStatus(value)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid habit entry status",
        ) from exc
