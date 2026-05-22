#!/usr/bin/env bash
set -euo pipefail

export POSTGRES_DB="${POSTGRES_DB:-habit_tracker}"
export POSTGRES_USER="${POSTGRES_USER:-habit_tracker}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-habit_tracker}"
export DATABASE_URL="${DATABASE_URL:-postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${POSTGRES_DB}}"

docker-entrypoint.sh postgres -c listen_addresses=127.0.0.1 &
postgres_pid="$!"

until pg_isready -h 127.0.0.1 -p 5432 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; do
  sleep 1
done

alembic upgrade head

uvicorn app.main:app --host 0.0.0.0 --port 8000 &
api_pid="$!"

terminate() {
  kill -TERM "${api_pid}" "${postgres_pid}" 2>/dev/null || true
  wait 2>/dev/null || true
}

trap terminate INT TERM

wait -n "${api_pid}" "${postgres_pid}"
exit_code="$?"
terminate
exit "${exit_code}"
