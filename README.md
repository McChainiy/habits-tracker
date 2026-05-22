# Месяц привычек

Минималистичный iOS-трекер месячного челленджа привычек.

Пользователь выбирает до пяти привычек на месяц, заранее задаёт наказание за пропуск и каждый день отмечает выполнение. Наказание является личным контрактом: приложение показывает его при пропуске, но не блокирует устройство.

## Структура

- `ios/` — SwiftUI MVP приложения.
- `backend/` — каркас будущего API на Python, FastAPI, PostgreSQL, SQLAlchemy async и Alembic.
- `docs/` — архитектурные решения и продуктовая спецификация.
- `index.html` — статичный визуальный прототип лендинга и первого экрана приложения.

## Быстрый запуск backend

Для локального backend-окружения используется Docker Compose:

```bash
docker compose up --build
```

После старта API доступен на `http://localhost:8001`, проверка здоровья:

```bash
curl http://localhost:8001/health
```

PostgreSQL доступен на `localhost:5433` с дефолтными значениями из `.env.example`.
При старте контейнер `api` автоматически выполняет `alembic upgrade head`.

Если Docker Hub недоступен, можно временно указать локальный Python base image:

```bash
PYTHON_BASE_IMAGE=fastapi-project-api:latest SKIP_REQUIREMENTS_INSTALL=true docker compose up --build
```

Полезные команды:

```bash
make docker-up
make docker-down
make docker-logs
make docker-migrate
```

## iOS

Планируемый стек:

- SwiftUI
- SwiftData
- iOS 17+
- локальное хранение на первом этапе

В текущей среде установлен только Command Line Tools, не полноценный Xcode, поэтому проект подготовлен как исходники SwiftUI и `project.yml` для генерации Xcode-проекта через XcodeGen.

Для запуска на iPhone или MacBook нужен установленный Xcode. Docker не запускает нативное iOS-приложение; он используется для backend и базы данных.

## Backend

Планируемый стек:

- Python 3.12+
- FastAPI
- PostgreSQL
- SQLAlchemy 2 async ORM
- Alembic

Backend нужен для следующего этапа: аккаунты, синхронизация и история между устройствами.

## Sync API

Данные принадлежат пользователю. На текущем этапе используется dev-заголовок:

```bash
X-User-Id: <user_uuid>
```

Основные endpoints:

```text
POST /api/v1/users
GET  /api/v1/users/me
GET  /api/v1/sync/changes?since=<iso_datetime>
POST /api/v1/sync/push
```

Синхронизация основана на `updated_at`: клиент запрашивает изменения после последнего `server_timestamp`, а локальные изменения отправляет через `sync/push`. Удаления передаются через `deleted_at`.
