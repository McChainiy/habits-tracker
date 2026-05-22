.PHONY: docker-up docker-down docker-logs docker-migrate docker-ps

docker-up:
	docker compose up --build

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f api db

docker-migrate:
	docker compose exec api alembic upgrade head

docker-ps:
	docker compose ps
