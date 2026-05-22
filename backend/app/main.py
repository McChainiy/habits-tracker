from fastapi import FastAPI

from app.api.routes import challenges, health


def create_app() -> FastAPI:
    app = FastAPI(title="Habit Tracker API", version="0.1.0")
    app.include_router(health.router)
    app.include_router(challenges.router, prefix="/api/v1")
    return app


app = create_app()
