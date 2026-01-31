# CTS System - Docker Compose Environment

Единая Docker Compose среда для разработки и тестирования распределенной системы арбитражной торговли.

## 🏗️ Архитектура

Система состоит из следующих компонентов:

- **MySQL** - общая база данных
- **HSM Service** - служба управления ключами и шифрования
- **CTS-Core** - центральный оркестратор (Phase 1.4-1.5)
- **Trader Daemon** - торговые демоны (3 экземпляра, Phase 2+)

## 🚀 Быстрый старт

### Предварительные требования

- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ свободной RAM
- 10GB+ свободного места на диске
- Git

### Установка

**1. Клонировать ct-system репозиторий:**

```bash
git clone <ct-system-url> ct-system
cd ct-system
```

**2. Клонировать проекты сервисов:**

```bash
# CTS-Core (центральный оркестратор)
git clone <cts-core-url> services/cts-core

# HSM Service (управление ключами)
git clone <hsm-service-url> services/hsm-service

# Trader Daemon (торговые демоны)
git clone <trader-daemon-url> services/trader-daemon

# Web UI (опционально)
git clone <web-ui-url> services/web-ui-go
```

**Альтернатива:** Если проекты уже склонированы в другом месте, используйте symlinks:

```bash
ln -s /path/to/existing/cts-core services/cts-core
ln -s /path/to/existing/hsm-service services/hsm-service
ln -s /path/to/existing/trader-daemon services/trader-daemon
```

**3. Настроить окружение:**

```bash
# Скопировать пример конфигурации
cp .env.example .env

# Отредактировать при необходимости
vim .env
```

**4. Запустить систему:**

```bash
# Запустить все сервисы
make up

# Или без Makefile:
docker compose up -d

# Проверить статус
make ps

# Просмотр логов
make logs-core
make logs-hsm
make logs-mysql
```

### Первый запуск (MySQL инициализация)

При первом запуске MySQL автоматически выполнит миграции из [services/cts-core/migrations](services/cts-core/migrations).

Ожидаемое время инициализации: 30-60 секунд.

## 📁 Структура проекта

```
ct-system/
├── docker-compose.yml       # Главный файл конфигурации
├── .env                     # Переменные окружения (не в git)
├── Makefile                 # Команды для управления
├── README.md                # Этот файл
├── ct-system.code-workspace # VS Code workspace
│
├── services/                # Все сервисы
│   ├── cts-core/           # CTS-Core сервис (git repo)
│   ├── hsm-service/        # HSM сервис (git repo)
│   ├── trader-daemon/      # Trader daemon (git repo)
│   └── mysql/              # MySQL конфиги
│
└── volumes/                # Docker volumes (не в git)
    ├── mysql-data/         # MySQL база данных
    └── hsm-tokens/         # HSM токены
```

## 🔧 Команды Makefile

### Основные команды

```bash
make up          # Запустить все сервисы
make down        # Остановить все сервисы
make restart     # Перезапустить все сервисы
make ps          # Показать статус сервисов
```

### Логи

```bash
make logs        # Все логи
make logs-core   # Логи CTS-Core
make logs-hsm    # Логи HSM
make logs-mysql  # Логи MySQL
```

### Тестирование

```bash
make test        # Запустить тесты CTS-Core
make test-hsm    # Запустить HSM integration тесты
make health      # Проверить здоровье всех сервисов
```

### Разработка

```bash
make build       # Пересобрать образы
make rebuild     # Пересобрать с нуля (без кэша)
make shell-core  # Открыть shell в CTS-Core
make shell-hsm   # Открыть shell в HSM
make shell-mysql # Открыть MySQL клиент
```

### Очистка

```bash
make clean       # Удалить все данные (ОПАСНО!)
```

## 🌐 Порты и эндпоинты

| Сервис    | Порт | Эндпоинт                    | Описание            |
|-----------|------|-----------------------------|---------------------|
| MySQL     | 3306 | localhost:3306              | MySQL database      |
| HSM       | 8443 | https://localhost:8443      | HSM API (TLS)       |
| CTS-Core  | 8080 | http://localhost:8080       | REST API (Phase 1.5+)|
| CTS-Core  | 8081 | ws://localhost:8081         | WebSocket (Phase 2+)|

### Health Checks

- MySQL: `docker compose exec mysql mysqladmin ping`
- HSM: `curl -k https://localhost:8443/health`
- CTS-Core: `curl http://localhost:8080/health`

## 🔐 Конфигурация

### Переменные окружения (.env)

```env
MYSQL_ROOT_PASSWORD=devroot123
MYSQL_DATABASE=ct_system
MYSQL_USER=devuser
MYSQL_PASSWORD=devpass123
TZ=Europe/Moscow
```

### Конфигурационные файлы

Каждый сервис монтирует свой `conf/` и `pki/` директории:

- **CTS-Core**: [services/cts-core/conf/config.yaml](services/cts-core/conf/config.yaml)
- **HSM**: [services/hsm-service/config.yaml](services/hsm-service/config.yaml)
- **Trader**: [services/trader-daemon/conf/config.ini](services/trader-daemon/conf/config.ini)

## 🧪 Тестирование

### Unit тесты

```bash
# CTS-Core
make test

# Из контейнера
docker compose exec cts-core go test -v ./...
```

### Integration тесты

```bash
# HSM Integration
make test-hsm

# Или вручную
docker compose exec cts-core go test -v -tags=integration ./internal/hsm/...
```

### Manual тестирование

```bash
# 1. Запустить окружение
make up

# 2. Проверить что все здорово
make health

# 3. Посмотреть логи
make logs-core

# 4. Подключиться к MySQL
make shell-mysql
# mysql> SHOW TABLES;
# mysql> SELECT * FROM sessions;
```

## 🐛 Troubleshooting

### MySQL не запускается

```bash
# Проверить логи
make logs-mysql

# Удалить данные и пересоздать
make clean
make up
```

### HSM не отвечает

```bash
# Проверить логи
make logs-hsm

# Проверить сертификаты
docker compose exec hsm ls -la /app/pki

# Пересобрать образ
make rebuild
docker compose up -d hsm
```

### CTS-Core не подключается к MySQL

```bash
# Проверить что MySQL готов
docker compose exec mysql mysqladmin ping

# Проверить переменные окружения
docker compose exec cts-core env | grep MYSQL

# Проверить конфигурацию
docker compose exec cts-core cat /app/conf/config.yaml
```

### Порты заняты

```bash
# Проверить какой процесс занимает порт
sudo lsof -i :3306
sudo lsof -i :8443
sudo lsof -i :8080

# Остановить существующие сервисы или изменить порты в docker-compose.yml
```

## 📚 Документация

- [Миграция на Docker](MIGRATE_SYS_TO_DOCKER.md) - План миграции
- [CTS-Core Architecture](services/cts-core/ARCHITECTURE.md)
- [CTS-Core Development Plan](services/cts-core/DEVELOPMENT_PLAN.md)
- [HSM Service API](services/hsm-service/API.md)
- [HSM Architecture](services/hsm-service/ARCHITECTURE.md)

## 🔄 Git Strategy

Проект использует двухуровневую git структуру:

- **Корневой репозиторий**: Docker Compose конфигурация, документация
- **Сервисы**: Каждый сервис имеет свой git репозиторий в `services/`

### Workflow

```bash
# Изменения в docker-compose.yml
cd /home/dev/docker/ct-system
git add docker-compose.yml
git commit -m "Update MySQL healthcheck"

# Изменения в коде CTS-Core
cd services/cts-core
git add internal/manager/session.go
git commit -m "Fix session timeout"
```

## 🎯 Roadmap

### ✅ Phase 1.4 (Current)
- MySQL, HSM, CTS-Core в Docker
- Session Manager
- Heartbeat механизм

### 🔄 Phase 1.5 (In Progress)
- REST API для управления
- Task Scheduler
- Load Balancing алгоритмы

### 📋 Phase 2 (Planned)
- WebSocket для Traders
- 3 Trader экземпляра
- Real-time мониторинг

### 🚀 Phase 3 (Future)
- Web UI
- Metrics & Dashboards
- Production deployment

## 👥 VS Code Multi-root Workspace

Для удобной работы со всеми проектами:

```bash
# Открыть workspace
code ct-system.code-workspace
```

Workspace включает:
- 🎛️ CTS-Core
- 🔐 HSM Service
- 🤖 Trader Daemon

## 📝 Примечания

- **Traders закомментированы**: До реализации WebSocket в Phase 2
- **Volumes не в git**: `volumes/` исключены из версионирования
- **Логи каждого сервиса**: В своих директориях `services/*/logs/`
- **Dev окружение**: Это development среда, не для production

## 🆘 Помощь

```bash
# Показать все доступные команды
make help

# Проверить статус
make ps

# Посмотреть что происходит
make logs
```

## 📧 Контакты

См. документацию каждого сервиса для деталей.

---

**Последнее обновление:** 31 января 2026
