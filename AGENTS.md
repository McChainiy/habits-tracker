# Правила проекта

- Основной язык проекта: Python.
- Код по умолчанию пишется в асинхронном стиле: `async`/`await`, асинхронные клиенты и неблокирующий I/O.
- Основная база данных: PostgreSQL.
- Для работы с базой данных используется SQLAlchemy ORM.
- Для SQLAlchemy предпочитать async API: `AsyncEngine`, `AsyncSession`, `async_sessionmaker`.
- Не добавлять синхронный доступ к базе данных без явной причины.
- Новые архитектурные решения подбирать под стек Python + async + PostgreSQL + SQLAlchemy.
- SQLAlchemy используется именно как ORM, а не только как SQL expression builder.
- Для миграций базы данных использовать Alembic.
