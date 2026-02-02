# CTS System - Docker Compose Environment

Единая Docker Compose среда для разработки и тестирования распределенной системы арбитражной торговли.

## ⚡ Быстро начать

```bash
# Для новичков (полная автоматизация):
./init-system.sh

# Для опытных (читай дальше):
# Смотри раздел "Быстрый старт" → "Ручная установка"
```

## 📚 Документация

- **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** - Общий план разработки (начните отсюда!)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Архитектура системы
- **[LOGGING_ANALYSIS.md](LOGGING_ANALYSIS.md)** - Анализ логирования (Priority 1)
- **[HSM_ROTATION.md](HSM_ROTATION.md)** - HSM key rotation (готово)
- **services/\*/DEVELOPMENT_PLAN.md** - Детальные планы сервисов

## 🏗️ Архитектура

Система состоит из следующих компонентов:

- **MySQL** - общая база данных
- **HSM Service** - служба управления ключами и шифрования (production-ready)
- **CTS-Core** - центральный оркестратор (Phase 1.3 complete, 1.4 in progress)
- **Trader Daemon** - торговые демоны (Phase 1 complete, Phase 2 planned)
- **Web UI** - административная панель (operational)

## 🚀 Быстрый старт

### Автоматическая установка (рекомендуется)

Для новичков рекомендуется использовать автоматический скрипт инициализации:

```bash
# Запустить интерактивный скрипт
./init-system.sh

# Или с опциями
./init-system.sh --skip-clone      # Пропустить клонирование репозиториев
./init-system.sh --skip-pki        # Использовать существующие сертификаты
./init-system.sh --skip-docker     # Не запускать Docker Compose
```

✨ Скрипт автоматически:
- Проверяет все зависимости
- Генерирует PKI инфраструктуру
- Клонирует (или проверяет) сервисы
- Инициализирует конфигурационные файлы
- Запускает Docker Compose
- Проверяет здоровье сервисов

---

### Ручная установка (пошаговый гайд)

#### Предварительные требования

- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ свободной RAM
- 10GB+ свободного места на диске
- Git
- **OpenSSL 1.1.1+** (для генерации PKI)
- **bash 4.0+** (для скриптов генерации)

### Установка зависимостей

#### Linux (Ubuntu/Debian)

```bash
# OpenSSL и другие необходимые утилиты
sudo apt-get update
sudo apt-get install -y openssl ca-certificates git

# Проверка версии
openssl version
# Output: OpenSSL 1.1.1 или выше
```

#### macOS

```bash
# Использовать Homebrew
brew install openssl

# Проверка версии
openssl version
```

#### Windows

Используйте WSL2 (Windows Subsystem for Linux) или Git Bash:

```bash
# WSL2 (рекомендуется)
wsl --install
# Затем внутри WSL выполнить команды как на Ubuntu

# Или Git Bash
# OpenSSL включен в Git for Windows
openssl version
```

#### Установка зависимостей

##### Linux (Ubuntu/Debian)

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

##### macOS

```bash
# Использовать Homebrew
brew install openssl bash

# Проверка версии
openssl version
bash --version
```

##### Windows

Используйте WSL2 (Windows Subsystem for Linux) или Git Bash:

```bash
# WSL2 (рекомендуется)
wsl --install
# Затем внутри WSL выполнить команды как на Ubuntu

# Или Git Bash
# OpenSSL включен в Git for Windows
openssl version
```

#### Пошаговая установка

**1. Клонировать ct-system репозиторий:**

```bash
git clone https://github.com/titaev-lv/cts-system-all-in-docker.git cts-system
cd cts-system
```

**2. Сгенерировать PKI инфраструктуру (сертификаты и ключи):**

Это требуется для установления mTLS соединений между сервисами.

```bash
# Генерируем Root CA + Intermediate CA иерархию
./scripts/pki/01-generate-ca.sh

# Генерируем серверные сертификаты (4 шт)
./scripts/pki/02-generate-server-certs.sh

# Генерируем клиентские сертификаты (16 шт)
./scripts/pki/03-generate-client-certs.sh

# Результат: volumes/pki/ директория с полной структурой сертификатов
# Все сертификаты автоматически монтируются в контейнеры
```

⏱️ **Время генерации:** 1-2 минуты

✅ **Что генерируется:**
- Root CA (самоподписанный trust anchor)
- Intermediate CA (подписан Root CA)
- 4 серверных сертификата (MySQL, HSM, CTS-Core, ClickHouse)
- 16 клиентских сертификатов (для mTLS между сервисами)

**3. Клонировать проекты сервисов:**

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

**4. Настроить окружение:**

Инициализируются автоматически, но можете отредактировать:

```bash
# Переменные окружения
cp .env.example .env
vim .env

# Конфигурация CTS-Core
vim services/cts-core/conf/config.ini

# Конфигурация HSM
vim services/hsm-service/config.yaml

# Конфигурация Trader Daemon
vim services/trader-daemon/conf/config.ini
```

**5. Запустить систему:**

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
- [MySQL SSL Configuration](docs/MYSQL_SSL_SETUP.md) - Настройка SSL и создание пользователей
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

## 🔗 Роль файлов в проекте

### 📖 README.md - **Полная документация**
**Назначение:** Главный справочник проекта

**Содержит:**
- ✅ Архитектуру системы
- ✅ Требования и установку
- ✅ Команды Makefile для повседневной работы
- ✅ Информацию о портах, здоровье и конфигурации
- ✅ Troubleshooting и решение проблем
- ✅ Ссылки на детальную документацию каждого сервиса
- ✅ Roadmap и планы развития

**Для кого:** Для опытных разработчиков, которые уже знают систему

**Как использовать:** Ищите нужный раздел и выполняйте команды вручную

---

### 🤖 init-system.sh - **Автоматизация для новичков**
**Назначение:** Полностью автоматизировать первую установку

**Выполняет:**
- ✅ Проверку всех зависимостей (Docker, OpenSSL, bash)
- ✅ Инициализацию .env файла
- ✅ Генерацию PKI инфраструктуры (сертификаты)
- ✅ Проверку/клонирование сервисов
- ✅ Инициализацию конфигурационных файлов
- ✅ Запуск Docker Compose
- ✅ Проверку здоровья сервисов

**Опции:**
```bash
./init-system.sh                    # Полная автоматизация
./init-system.sh --skip-clone       # Не клонировать репозитории
./init-system.sh --skip-pki         # Использовать существующие сертификаты
./init-system.sh --skip-docker      # Не запускать Docker
```

**Для кого:** Для новичков и в production

**Как использовать:** Просто запустите и следуйте подсказкам

---

### 📋 Рекомендуемый workflow

**Для новичков (первый раз):**
```bash
1. chmod +x init-system.sh          # Сделать скрипт исполняемым
2. ./init-system.sh                 # Полная автоматизация
3. Читаем README.md для понимания   # Разбираемся что произошло
4. make logs                        # Смотрим логи
```

**Для разработки (по дням):**
```bash
# Запустить окружение
make up

# Смотреть логи конкретного сервиса
make logs-core
make logs-hsm

# Перезапустить сервис после изменений
docker compose restart cts-core

# Остановить все
make down
```

**Для переустановки:**
```bash
./init-system.sh --skip-clone       # Повторная инициализация
./init-system.sh --skip-pki         # Если PKI уже есть
```

---

### ⚙️ Когда какой файл использовать

| Задача | Где искать |
|--------|-----------|
| **Первая установка** | `./init-system.sh` |
| **Понять как работает система** | `README.md` - раздел Архитектура |
| **Запустить сервисы заново** | `make up` или README раздел Команды |
| **Посмотреть логи** | `make logs` или README раздел Логи |
| **Узнать про порты и здоровье** | README раздел Порты и Health Checks |
| **Решить проблему** | README раздел Troubleshooting |
| **Узнать про Roadmap** | README раздел Roadmap |
| **Развернуть в production** | `./init-system.sh --skip-clone` |

## �📝 Примечания

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
