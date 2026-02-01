.PHONY: up down restart logs ps test clean build rebuild help

# Запустить все сервисы
up:
	docker compose up -d

# Остановить все сервисы
down:
	docker compose down

# Перезапустить все
restart:
	docker compose restart

# Просмотр логов
logs:
	docker compose logs -f

logs-core:
	tail -n 100 -f services/cts-core/logs/error.log

logs-hsm:
	docker compose logs -f hsm

logs-mysql:
	docker compose logs -f mysql

logs-web-ui:
	docker compose logs -f web-ui

logs-trader-1:
	tail -n 100 -f services/trader-daemon/logs/error.log

logs-trader-2:
	docker compose logs -f trader-1

logs-trader-2:
	docker compose logs -f trader-2

logs-trader-3:
	docker compose logs -f trader-3

# Статус сервисов
ps:
	docker compose ps

# Тесты
test:
	@echo "Running CTS-Core tests..."
	docker compose exec cts-core go test -v ./...

test-hsm:
	@echo "Running HSM integration tests..."
	docker compose exec cts-core go test -v -tags=integration ./internal/hsm/...

# Пересборка образов
build:
	docker compose build

rebuild:
	docker compose build --no-cache

# Очистка (DANGER: удаляет volumes!)
clean:
	@echo "WARNING: This will delete all data!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose down -v
	rm -rf volumes/mysql-data/*
	rm -rf volumes/hsm-tokens/*

# Shell в контейнерах
shell-core:
	docker compose exec cts-core /bin/sh

shell-hsm:
	docker compose exec hsm /bin/sh

shell-mysql:
	docker compose exec mysql mysql -u${MYSQL_USER:-devuser} -p${MYSQL_PASSWORD:-devpass123} ${MYSQL_DATABASE:-ct_system}

shell-trader-1:
	docker compose exec trader-1 /bin/sh

# Создать .env.example из текущего .env
env-example:
	@if [ -f .env ]; then \
		sed 's/=.*/=/' .env > .env.example && \
		echo ".env.example created"; \
	else \
		echo "Error: .env not found"; \
		exit 1; \
	fi

# Проверка здоровья сервисов
health:
	@echo "=== Service Health Status ==="
	@docker compose ps
	@echo ""
	@echo "=== MySQL ==="
	@docker compose exec mysql mysqladmin ping -h localhost || echo "MySQL: UNHEALTHY"
	@echo ""
	@echo "=== HSM ==="
	@docker compose exec hsm wget --no-check-certificate -qO- https://localhost:8443/health || echo "HSM: UNHEALTHY"
	@echo ""
	@echo "=== CTS-Core ==="
	@docker compose exec cts-core wget -qO- http://localhost:8080/health || echo "CTS-Core: UNHEALTHY"

# Помощь
help:
	@echo "Available commands:"
	@echo "  make up            - Start all services"
	@echo "  make down          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo "  make logs          - View all logs"
	@echo "  make logs-core     - View CTS-Core logs"
	@echo "  make logs-hsm      - View HSM logs"
	@echo "  make logs-mysql    - View MySQL logs"
	@echo "  make ps            - Show service status"
	@echo "  make test          - Run CTS-Core tests"
	@echo "  make test-hsm      - Run HSM integration tests"
	@echo "  make build         - Build Docker images"
	@echo "  make rebuild       - Rebuild images from scratch"
	@echo "  make clean         - Remove all data (DANGER!)"
	@echo "  make health        - Check service health"
	@echo "  make shell-core    - Open shell in CTS-Core"
	@echo "  make shell-hsm     - Open shell in HSM"
	@echo "  make shell-mysql   - Open MySQL client"
	@echo "  make env-example   - Create .env.example from .env"
