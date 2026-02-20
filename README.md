# CTS System - Docker Compose Environment

Единая Docker Compose среда для разработки и тестирования распределенной системы арбитражной торговли.

## 📚 Документация

- **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** - Общий план разработки (начните отсюда!)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Архитектура системы
- **[LOGGING.md](LOGGING.md)** - Единый документ по логированию (Priority 1)
- **[TESTING.md](TESTING.md)** - Тестовая стратегия (service-local / integration / E2E)
- **[HSM_ROTATION.md](HSM_ROTATION.md)** - HSM key rotation (готово)
- **services/\*/DEVELOPMENT_PLAN.md** - Детальные планы сервисов

## 🏗️ Архитектура

Система состоит из следующих компонентов:

- **MySQL** - общая база данных
- **HSM Service** - служба управления ключами и шифрования (production-ready)
- **CTS-Core** - центральный оркестратор (Phase 1.3 complete, 1.4 in progress)
- **Trader** - торговые сервисы (Phase 1 complete, Phase 2 planned)
- **Web UI** - административная панель (operational)

## Предварительные требования

- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ свободной RAM
- 10GB+ свободного места на диске
- Git
- **OpenSSL 1.1.1+** (для генерации PKI)
- **bash 4.0+** (для скриптов генерации)

## 📦 Установка зависимостей

### Linux (Ubuntu/Debian)

```bash
# OpenSSL и другие необходимые утилиты
sudo apt-get update
sudo apt-get install -y openssl ca-certificates git bash

# Проверка версии
openssl version
# Output: OpenSSL 1.1.1 или выше
bash --version
# Output: GNU bash, version 4.0 или выше
```

### macOS

```bash
# Использовать Homebrew
brew install openssl bash

# Проверка версии
openssl version
bash --version
```

### Windows

Используйте WSL2 (Windows Subsystem for Linux) или Git Bash:

```bash
# WSL2 (рекомендуется)
wsl --install
# Затем внутри WSL выполнить команды как на Ubuntu

# Или Git Bash
# OpenSSL включен в Git for Windows
openssl version
```

## 🚀 Быстрый старт

### 1. Клонировать репозиторий

```bash
git clone https://github.com/titaev-lv/cts-system-all-in-docker.git cts-system
cd cts-system
```

### 2. Запустить инициализацию

```bash
chmod +x init-system.sh
./init-system.sh
```

**Скрипт выполнит:**
- ✅ Проверку всех зависимостей (Docker, OpenSSL, bash)
- ✅ Генерацию PKI инфраструктуры (Root CA + Intermediate CA)
- ✅ Генерацию 4 серверных и 16 клиентских сертификатов
- ✅ Проверку/клонирование сервисов из GitHub
- ✅ Инициализацию конфигурационных файлов (.env, config.yaml)
- ✅ Запуск только доступных сервисов (MySQL + клонированные)
- ✅ Создание базы данных `cts-system` в MySQL
- ✅ Загрузку начальных данных из `volumes/mysql-dump/init.sql` (если файл существует)
- ✅ Проверку здоровья сервисов

**Опции (если нужны):**
```bash
./init-system.sh --skip-clone       # Если сервисы уже клонированы
./init-system.sh --skip-pki         # Если сертификаты уже есть
./init-system.sh --skip-docker      # Только подготовить, не запускать
```

⏱️ **Время первого запуска:** 2-3 минуты (PKI генерация ~1-2 мин)

✨ **После успешного завершения:**
- MySQL будет готов к подключению: `localhost:3306`
- HSM API доступен: `https://localhost:8443`
- CTS-Core API доступен: `http://localhost:8080`
- Все логи смотрите через: `make logs`

### 3. Проверить статус

```bash
# Показать все запущенные контейнеры
make ps

# Посмотреть логи всех сервисов
make logs

# Посмотреть логи конкретного сервиса
make logs-core
make logs-hsm
make logs-mysql
```

### Первый запуск (MySQL инициализация)

При первом запуске скрипт автоматически:

1. **Создает базу данных** `cts-system`
2. **Загружает начальные данные** из `volumes/mysql-dump/init.sql` (если файл существует)
3. **Проверяет готовность MySQL** перед загрузкой данных

**Для загрузки своих данных:**

Поместите SQL дамп в файл `volumes/mysql-dump/init.sql`, и он будет автоматически загружен при запуске скрипта.

```bash
# Пример: экспортировать существующую БД
mysqldump -u user -p database > volumes/mysql-dump/init.sql

# Затем запустить инициализацию
./init-system.sh
```

Ожидаемое время инициализации: 30-60 секунд (зависит от размера init.sql).

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
│   ├── trader/             # Trader service (git repo)
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
- **Trader**: [services/trader/conf/config.yaml](services/trader/conf/config.yaml)

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
- [MySQL SSL Configuration](docs/MYSQL_SSL_SETUP.md) - Настройка SSL и создание пользователей
- [CTS-Core Architecture](services/cts-core/ARCHITECTURE.md)
- [CTS-Core Development Plan](services/cts-core/DEVELOPMENT_PLAN.md)
- [HSM Service API](services/hsm-service/API.md)
- [HSM Architecture](services/hsm-service/ARCHITECTURE.md)
- [Testing Strategy](TESTING.md) - Матрица и уровни тестирования CT-SYSTEM

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
- 🤖 Trader

##  Примечания

- **Trader работает в outbound-only режиме**: задачи и оркестрация через CTS-Core
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

**Последнее обновление:** 3 февраля 2026
