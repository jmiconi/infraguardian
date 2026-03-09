up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f

status:
	docker ps

restart:
	docker compose restart
