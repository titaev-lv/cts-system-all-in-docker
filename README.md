# CTS System - Docker Compose Environment

Единая Docker Compose среда для разработки и тестирования распределенной системы арбитражной торговли.

## 📚 Документация

- **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** - Общий план разработки (начните отсюда!)
- **[LOGGING.md](LOGGING.md)** - Единый документ по логированию (Priority 1)
- **[TESTING.md](TESTING.md)** - Тестовая стратегия (service-local / integration / E2E)
- **[AUDIT_SYSTEM_PLAN.md](AUDIT_SYSTEM_PLAN.md)** - План аудита и трассировки событий
- **[docs/MYSQL_SSL_SETUP.md](docs/MYSQL_SSL_SETUP.md)** - Настройка SSL для MySQL
- **[docs/PKI_INFRASTRUCTURE_PLAN.md](docs/PKI_INFRASTRUCTURE_PLAN.md)** - PKI инфраструктура
- **[docs/WS_TRANSPORT_CORE_TRADER.md](docs/WS_TRANSPORT_CORE_TRADER.md)** - Транспортный уровень WebSocket между CTS-Core и Trader
- **services/\*/DEVELOPMENT_PLAN.md** - Детальные планы сервисов

## 🏗️ Архитектура

Система состоит из следующих компонентов:

- **MySQL** - общая база данных
- **HSM Service** - служба управления ключами и шифрования (production-ready)
- **CTS-Core** - центральный оркестратор (Phase 2 завершена: WS lifecycle + session persistence + scheduler skeleton)
- **Trader** - торговые сервисы (Phase 1 complete, интеграция с CTS-Core в развитии)
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

### 2.1 Профили запуска (`proxy` / `direct`)

По умолчанию Docker Compose читает `COMPOSE_PROFILES` из `.env` в корне проекта.
Рекомендуемый дефолт:

```env
COMPOSE_PROFILES=proxy
```

Ручное переключение профилей:

```bash
# Proxy mode (nginx + web-ui)
docker compose --profile proxy up -d

# Direct mode (web-ui без nginx)
docker compose --profile direct up -d
```

### 2.2 Короткий статус по web-ui dual-mode

- Реализованы оба режима запуска: `direct` и `proxy`.
- В `proxy` режиме TLS/HTTP2 и статика обслуживаются `nginx`, backend работает как internal upstream (`web-ui:8080`).
- Добавлен smoke-сценарий: `make smoke-web-ui` (включая проверку `X-Request-ID`, redirect и optional secure-cookie).
- Документация по `proxy.*` и forwarded headers вынесена в `services/web-ui-go/config/README.md`.

**Скрипт выполнит:**
- ✅ Проверку всех зависимостей (Docker, OpenSSL, bash)
- ✅ Генерацию PKI инфраструктуры (Root CA + Intermediate CA)
- ✅ Генерацию 4 серверных и 16 клиентских сертификатов
- ✅ Проверку/клонирование сервисов из GitHub
- ✅ Инициализацию конфигурационных файлов (.env, config.proxy.yaml, config.direct.yaml)
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
- CTS-Core API доступен: `https://localhost:8080`
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
├── cts-system.code-workspace # VS Code workspace
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
make smoke-web-ui # Smoke для web-ui direct/proxy
make smoke-core-ws # Smoke для CTS-Core WS (wss + mTLS + pending gate)
make health      # Проверить здоровье всех сервисов
```

#### Smoke-проверки web-ui (direct/proxy)

```bash
# Базовый прогон (статика, proxy/direct, request-id, redirect)
make smoke-web-ui

# Полный прогон с проверкой secure-cookie (нужны валидные креды web-ui)
WEB_UI_SMOKE_LOGIN_USER=<login> \
WEB_UI_SMOKE_LOGIN_PASS=<password> \
make smoke-web-ui
```

Что проверяется:
- `direct` mode: статика отдается `web-ui-direct` (Gin)
- `proxy` mode: статика отдается `nginx`, backend `/assets` возвращает `404` (Gin static отключен)
- `proxy` mode: `X-Request-ID` присутствует в ответе и совпадает с `web-ui-go` логами
- `proxy` mode: HTTP→HTTPS redirect для `/login`
- `proxy` mode (опционально): `Login`/`CTToken` cookies имеют `Secure` при HTTPS на edge

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
| CTS-Core  | 8080-8081 | https://localhost:8080/health | REST/health (TLS в compose-профиле) |
| CTS-Core  | 8080-8081 | wss://localhost:8080/ws       | WebSocket runtime |

### Health Checks

- MySQL: `docker compose exec mysql mysqladmin ping`
- HSM: `curl -k https://localhost:8443/health`
- CTS-Core: `curl -k https://localhost:8080/health`

### CTS-Core Phase 2 smoke

```bash
make smoke-core-ws
```

## 🔐 Конфигурация

### Переменные окружения (.env)

```env
MYSQL_ROOT_PASSWORD=devroot123
MYSQL_DATABASE=ct_system
MYSQL_USER=devuser
MYSQL_PASSWORD=devpass123
TZ=Europe/Moscow
COMPOSE_PROFILES=proxy
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

- [MySQL SSL Configuration](docs/MYSQL_SSL_SETUP.md) - Настройка SSL и создание пользователей
- [PKI Infrastructure Plan](docs/PKI_INFRASTRUCTURE_PLAN.md) - PKI и сертификаты для сервисов
- [CTS-Core Architecture](services/cts-core/ARCHITECTURE.md)
- [CTS-Core Development Plan](services/cts-core/DEVELOPMENT_PLAN.md)
- [CTS-Core Phase 2 Smoke Runbook](services/cts-core/guides/PHASE2_SMOKE_RUNBOOK.md)
- [HSM Service API](services/hsm-service/API.md)
- [HSM Architecture](services/hsm-service/ARCHITECTURE.md)
- [Audit System Plan](AUDIT_SYSTEM_PLAN.md) - единая модель audit/event chain
- [Testing Strategy](TESTING.md) - Матрица и уровни тестирования CT-SYSTEM

## 🔄 Git Strategy

Проект использует двухуровневую git структуру:

- **Корневой репозиторий**: Docker Compose конфигурация, документация
- **Сервисы**: Каждый сервис имеет свой git репозиторий в `services/`

### Workflow

```bash
# Изменения в docker-compose.yml
cd /home/dev/docker/cts-system
git add docker-compose.yml
git commit -m "Update MySQL healthcheck"

# Изменения в коде CTS-Core
cd services/cts-core
git add internal/manager/session.go
git commit -m "Fix session timeout"
```

## 🎯 Roadmap

### ✅ Phase 1.4 (Done)
- MySQL, HSM, CTS-Core в Docker
- Session Manager
- Heartbeat механизм

### ✅ Phase 2 (Done)
- WebSocket runtime для Traders (`register`, `heartbeat`, `ack/error`)
- Session lifecycle + persistence в `TRADER_SESSION`
- Базовый scheduler cycle + runtime telemetry
- Compose smoke runbook и deterministic smoke tooling

### ✅ Phase 1.5 Finalization (Done)
- `/metrics`
- Prometheus wiring
- integration tests

### 🚀 Phase 3 (Future)
- Scheduler business logic и расширенные assignment rules
- Зафиксированное правило выбора trader для массива бирж:
    - CTS-Core выбирает только исполнителя для набора `exchange_ids`.
    - Решение `buy/sell` принимает сам trader (не CTS-Core).
    - Ранжирование: приоритет latency-профиля по требуемым биржам с защитой от выбросов + нелинейный штраф по нагрузке от trader.
    - Короткая формула (меньше = лучше): `score = latency_profile_ms + 1000 * (load_index^2)`.
    - Расчет (v1):
        - `latency_profile_ms` = робастный профиль задержек по всем `exchange_ids` (учитываем worst/p95 и разброс между биржами).
        - `load_index` в диапазоне `0..1` формируется на стороне trader (CPU + RAM + network + queue).
        - `load_index^2` усиливает штраф около насыщения (near saturation).
        - Коэффициент `1000` приводит load-штраф к масштабу миллисекунд, чтобы его можно было складывать с latency.
    - Trader после подключения регулярно шлет телеметрию (heartbeat + metrics), CTS-Core агрегирует ее в профиль ранжирования.
    - В `trader.register_ack` core отдает каталог доступных бирж (включая `exchange_id` и endpoint-данные), после чего trader проводит тест подключений и отправляет стартовые метрики.
    - Тесты задержек выполняются по всем биржам из capabilities trader (не только по одной бирже по запросу).
- Расширение интеграции trader + web-ui
- Production deployment hardening

## 👥 VS Code Multi-root Workspace

Для удобной работы со всеми проектами:

```bash
# Открыть workspace
code cts-system.code-workspace
```

Workspace включает:
- 🎛️ CTS-Core
- 🔐 HSM Service
- 🤖 Trader

##  Примечания

- **Trader работает в outbound-only режиме**: задачи и оркестрация через CTS-Core
- **WS identity policy (trader channel)**: `trader_id` берется только из CN клиентского сертификата; `payload.trader_id` не участвует в идентификации; допускаются только сертификаты `OU=Trading`.
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

**Последнее обновление:** 14 марта 2026
