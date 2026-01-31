# План миграции на единую Docker Compose среду

> **⚠️ ВАЖНО: НЕ КОММИТИТЬ В GIT**  
> **Цель:** Поднять всю распределенную систему (MySQL, HSM, CTS-Core, 3 Traders) в Docker Compose для удобной разработки и тестирования

---

## 📋 КАК ИСПОЛЬЗОВАТЬ ЭТОТ ДОКУМЕНТ

**Если вы вернулись к этому документу после перерыва:**

1. **Текущий статус:** Смотрите секцию "Текущий прогресс" ниже
2. **Что делать дальше:** Смотрите секцию "Следующие шаги"
3. **Вопросы для AI:** Дайте AI этот файл и спросите "Что делаем дальше с миграцией на Docker?"

**Контекст проекта:**
- **Проект:** CTS-Core - центральный оркестратор для распределенной системы арбитражной торговли
- **Компоненты:** MySQL (БД), HSM (шифрование), CTS-Core (оркестратор), Traders (торговые демоны)
- **Текущая проблема:** Все компоненты запускаются отдельно, нет единой dev-среды
- **Решение:** Единый docker-compose.yml который поднимает ВСЁ одной командой

---

## 📊 ТЕКУЩИЙ ПРОГРЕСС

**Статус:** � Структура готова, git настроен, ожидает docker-compose

**Что сделано:**
- ✅ Создан этот документ с планом миграции
- ✅ Директория `/home/dev/docker/ct-system/` создана
- ✅ Проекты скопированы в `services/` (cts-core, hsm-service, trader-daemon, web-ui-go, mysql)
- ✅ Git инициализирован в корне `/home/dev/docker/ct-system/`
- ✅ Git сохранен в каждом сервисе (cts-core, hsm-service, trader-daemon)
- ⏳ Ожидает: перенос данных БД
- ⏸️ Ожидает: создание docker-compose.yml и конфигурационных файлов

**Следующий шаг:** Создать docker-compose.yml, .env, Makefile и запустить систему

---

## 🗂️ ЦЕЛЕВАЯ СТРУКТУРА (NEW)

Новая организация проектов (равноправная, без "other-sub-system"):

```
/home/dev/ct-system/              # Новая корневая директория
│
├── docker-compose.yml             # ⭐ ГЛАВНЫЙ файл (без суффикса dev)
├── .env                           # Переменные окружения
├── Makefile                       # Команды для управления
├── README.md                      # Инструкция по запуску
├── .gitignore                     # Игнорировать volumes/
│
├── services/                      # Все сервисы равноправно
│   ├── mysql/                     # MySQL конфиг
│   │   └── initdb/                # SQL миграции (symlink)
│   │
│   ├── cts-core/                  # Git repo (symlink или submodule)
│   │   ├── .git/
│   │   ├── Dockerfile
│   │   ├── logs/                  # Свои логи
│   │   ├── state/                 # Свой state
│   │   └── ...
│   │
│   ├── hsm-service/               # Git repo (symlink или submodule)
│   │   ├── .git/
│   │   ├── Dockerfile
│   │   ├── data/                  # Токены HSM
│   │   └── ...
│   │
│   ├── trader-daemon/             # Git repo (symlink или submodule)
│   │   ├── .git/
│   │   ├── Dockerfile
│   │   └── ...
│   │
│   └── www-go/                    # Git repo (опционально)
│       └── ...
│
└── volumes/                       # Docker volumes (НЕ в git)
    ├── mysql-data/                # MySQL data
    ├── hsm-tokens/                # HSM SoftHSM tokens
    └── .gitkeep
```

**Ключевые изменения:**
- 🔄 Все проекты в `services/` на равных правах (не "other-sub-system")
- 📝 `docker-compose.yml` без суффикса "dev" (это и есть dev-среда по умолчанию)
- 📂 Каждый сервис имеет СВОИ `logs/` и `state/` внутри своей директории
- 🔗 Проекты можно держать как symlinks к текущим git репозиториям

---

## 🔄 ВАРИАНТЫ ОРГАНИЗАЦИИ GIT РЕПОЗИТОРИЕВ

### ⭐ РЕКОМЕНДУЕМЫЙ ПОДХОД: Двухуровневая система

**Идея:** Создать НОВЫЙ git репозиторий для Docker окружения + сохранить существующие репозитории сервисов

```
/home/dev/ct-system/               # 🆕 НОВЫЙ Git репозиторий (orchestration)
├── .git/                           # Git для docker-compose, конфигов, документации
├── docker-compose.yml
├── Makefile
├── .env
└── services/
    ├── cts-core/                   # ✅ СВОЙ Git репозиторий (код CTS-Core)
    │   └── .git/
    ├── hsm-service/                # ✅ СВОЙ Git репозиторий (код HSM)
    │   └── .git/
    └── trader-daemon/              # ✅ СВОЙ Git репозиторий (код Trader)
        └── .git/
```

**Как это работает:**

1. **Большой репозиторий** (`/home/dev/cts-system/.git`):
   - Хранит: docker-compose.yml, Makefile, README.md, .env.example
   - Версионирует: настройки окружения, документацию
   - НЕ хранит: код сервисов (они в своих репозиториях)

2. **Репозитории сервисов** (каждый `services/*/. git`):
   - Хранят: код, тесты, конфиги
   - Разрабатываются независимо
   - Могут иметь свои релизы и ветки

### Вариант 1: Symlinks + главный репозиторий (БЫСТРЫЙ СТАРТ)

```bash
# 1. Создать новую директорию и инициализировать Git
mkdir -p /home/dev/ct-system
cd /home/dev/ct-system
git init

# 2. Создать .gitignore (исключить services и volumes)
cat > .gitignore << 'EOF'
# Сервисы - отдельные репозитории
services/

# Данные - не в git
volumes/
*.log
.env

# Разрешить .env.example
!.env.example
EOF

# 3. Создать symlinks к существующим репозиториям
mkdir -p services
cd services
ln -s /home/dev/docker/cts-core ./cts-core
ln -s /home/dev/docker/other-sub-system/hsm-service ./hsm-service
ln -s /home/dev/docker/other-sub-system/daemon2 ./trader-daemon

# 4. Вернуться в корень и создать файлы
cd /home/dev/ct-system
# Создать docker-compose.yml, Makefile, README.md (см. секции ниже)

# 5. Первый коммит
git add .
git commit -m "Initial: Docker Compose orchestration for CTS system"
```

**Плюсы:**
- ✅ Быстро настроить (5 минут)
- ✅ Сервисы остаются в своих git репозиториях
- ✅ Изменения в сервисах коммитятся в их репозитории
- ✅ Docker настройки коммитятся в главный репозиторий
- ✅ Можно откатиться за минуту

**Минусы:**
- ⚠️ Symlinks могут сломаться при переименовании
- ⚠️ Не работает на Windows без admin прав

### Вариант 2: Git Submodules (ПРОДВИНУТЫЙ)

```bash
# 1. Создать главный репозиторий
mkdir -p /home/dev/ct-system
cd /home/dev/ct-system
git init

# 2. Добавить сервисы как submodules
mkdir -p services
git submodule add /home/dev/docker/cts-core services/cts-core
git submodule add /home/dev/docker/other-sub-system/hsm-service services/hsm-service
git submodule add /home/dev/docker/other-sub-system/daemon2 services/trader-daemon

# 3. Коммит
git commit -m "Add services as submodules"
```

**Плюсы:**
- ✅ Git нативное решение
- ✅ Версионирует связь между главным репо и версиями сервисов
- ✅ Можно указать конкретный commit каждого сервиса
- ✅ Работает на всех платформах

**Минусы:**
- ⚠️ Сложнее в использовании (git submodule update --init)
- ⚠️ Нужно помнить обновлять submodules
- ⚠️ Конфликты если забыть зафиксировать версию

### Вариант 3: Переместить всё (НЕ РЕКОМЕНДУЮ)

```bash
# Переместить физически все репозитории
mv /home/dev/docker/cts-core /home/dev/ct-system/services/
mv /home/dev/docker/other-sub-system/hsm-service /home/dev/ct-system/services/
```

**Плюсы:**
- ✅ Всё в одном месте

**Минусы:**
- ❌ Теряются пути в IDE/конфигах
- ❌ Сложно вернуться назад
- ❌ Нужно переносить всё сразу

### 🎯 ВЫБРАННЫЙ ВАРИАНТ

**Используется:** Копирование проектов + двухуровневая git система ✅

**Реализовано:**
- ✅ Проекты физически скопированы в `services/`
- ✅ Каждый сервис сохранил свой `.git/` (независимые репозитории)
- ✅ Корневая директория имеет свой git для docker-compose и конфигов
- ✅ Структура соответствует "Варианту 2: Двухуровневая система"

**Преимущества:**
- Полная независимость сервисов
- Нет проблем с symlinks
- Удобно работать в VS Code
- Легко добавлять новые сервисы

**Текущая структура Git:**

```
📁 /home/dev/docker/ct-system/    → ✅ git repo: оркестрация
   ├── .git/                       → ✅ История docker-compose, настроек
   ├── docker-compose.yml          → ✅ Коммитится в главный репо
   ├── Makefile                    → ✅ Коммитится в главный репо
   ├── README.md                   → ✅ Коммитится в главный репо
   ├── .env.example                → ✅ Коммитится в главный репо
   ├── .env                        → ❌ В .gitignore
   ├── .gitignore                  → ✅ Исключает services/ и volumes/
   └── services/                   → ❌ В .gitignore (но внутри есть свои .git)
       ├── cts-core/               → ✅ КОПИЯ с .git/
       │   └── .git/               → ✅ Независимый репозиторий
       ├── hsm-service/            → ✅ КОПИЯ с .git/
       │   └── .git/               → ✅ Независимый репозиторий
       ├── trader-daemon/          → ✅ КОПИЯ с .git/
       │   └── .git/               → ✅ Независимый репозиторий
       ├── mysql/                  → ⚪ Конфиги (git не нужен)
       └── web-ui-go/              → ⚪ КОПИЯ (можно добавить .git позже)
```

**Workflow:**

```bash
# Изменения в docker-compose.yml
cd /home/dev/ct-system
vim docker-compose.yml
git add docker-compose.yml
git commit -m "Add healthcheck for MySQL"
git push

# Изменения в коде CTS-Core
cd /home/dev/ct-system/services/cts-core
vim internal/manager/session.go
git add internal/manager/session.go
git commit -m "Fix session timeout"
git push

# Всё работает независимо! 🎉
```

---

## 🐋 DOCKER COMPOSE ФАЙЛ

**Файл:** `/home/dev/ct-system/docker-compose.yml`

```yaml
version: '3.8'

services:
  # 1. MySQL - общая БД
  mysql:
    image: mysql:9
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-devroot123}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-ct_system}
      MYSQL_USER: ${MYSQL_USER:-devuser}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-devpass123}
    volumes:
      - ./volumes/mysql-data:/var/lib/mysql
      - ./services/cts-core/migrations:/docker-entrypoint-initdb.d:ro
    ports:
      - "3306:3306"
    networks:
      - cts-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # 2. HSM Service
  hsm:
    build:
      context: ./services/hsm-service
      dockerfile: Dockerfile
    container_name: hsm
    volumes:
      - ./services/hsm-service/config.yaml:/app/config.yaml:ro
      - ./services/hsm-service/pki:/app/pki:ro
      - ./volumes/hsm-tokens:/app/data/tokens
    ports:
      - "8443:8443"
    networks:
      - cts-net
    healthcheck:
      test: ["CMD", "curl", "-k", "https://localhost:8443/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # 3. CTS-Core (оркестратор)
  cts-core:
    build:
      context: ./services/cts-core
      dockerfile: Dockerfile
    container_name: cts-core
    depends_on:
      mysql:
        condition: service_healthy
      hsm:
        condition: service_healthy
    volumes:
      - ./services/cts-core/conf:/app/conf:ro
      - ./services/cts-core/pki:/app/pki:ro
      - ./services/cts-core/logs:/app/logs        # Свои логи
      - ./services/cts-core/state:/app/state      # Свой state
    environment:
      - TZ=Europe/Moscow
      - CTS_ENVIRONMENT=development
      - CTS_MYSQL_HOST=mysql
      - CTS_MYSQL_PASSWORD=${MYSQL_PASSWORD:-devpass123}
    ports:
      - "8080:8080"  # REST API (Phase 1.5+)
      - "8081:8081"  # WebSocket (Phase 2+)
    networks:
      - cts-net
    restart: unless-stopped

  # 4-6. Traders (закомментированы до Phase 2)
  # trader-1:
  #   build:
  #     context: ./services/trader-daemon
  #     dockerfile: Dockerfile
  #   container_name: trader-1
  #   depends_on:
  #     - cts-core
  #     - hsm
  #   volumes:
  #     - ./services/trader-daemon/conf:/app/conf:ro
  #     - ./services/trader-daemon/pki:/app/pki:ro
  #     - ./services/trader-daemon/logs:/app/logs  # Свои логи
  #   environment:
  #     - TRADER_ID=trader-1
  #     - TRADER_NAME=Binance-Trader-1
  #     - CTS_CORE_URL=https://cts-core:8080
  #     - HSM_URL=https://hsm:8443
  #   networks:
  #     - cts-net
  #   restart: unless-stopped

networks:
  cts-net:
    driver: bridge
    name: cts-network

volumes:
  mysql-data:
  hsm-tokens:
```

**Ключевые моменты:**
- 💾 Каждый сервис монтирует СВОИ `logs/` и `state/`
- 🔗 Имена контейнеров простые: `mysql`, `hsm`, `cts-core` (без префикса dev)
- 📦 `volumes/` только для shared data (mysql-data, hsm-tokens)
- 🔌 Traders закомментированы - включим после Phase 2

---

## 🎯 VS CODE: РАБОТА С НЕСКОЛЬКИМИ ПРОЕКТАМИ

### Проблема: 
Каждый сервис - отдельный git репозиторий. Как работать со всеми сразу?

### Решение: Multi-root Workspace

**Что это:** Специальный файл `.code-workspace` который позволяет открыть несколько проектов в одном окне VS Code.

**Файл:** `/home/dev/ct-system/ct-system.code-workspace`

```json
{
  "folders": [
    {
      "path": "services/cts-core",
      "name": "🎛️ CTS-Core"
    },
    {
      "path": "services/hsm-service",
      "name": "🔐 HSM"
    },
    {
      "path": "services/trader-daemon",
      "name": "🤖 Trader"
    }
  ],
  "settings": {
    "files.exclude": {
      "**/volumes": true
    }
  }
}
```

**Использование:**
```bash
# Открыть все проекты сразу
code /home/dev/ct-system/ct-system.code-workspace

# ИЛИ через меню VS Code:
# File → Open Workspace from File → выбрать cts-system.code-workspace
```

**Что получите:**
- 📂 Все 3 проекта видны в Explorer слева
- 🔍 Поиск работает по всем проектам сразу
- 🐛 Можно дебажить любой сервис
- 📝 Каждый проект сохраняет свой .git

**Альтернатива:** Если не нужно - просто открывайте каждый проект отдельно. Workspace не обязателен.

---

## ⚙️ MAKEFILE ДЛЯ УПРАВЛЕНИЯ

**Файл:** `/home/dev/ct-system/Makefile`

```makefile
.PHONY: up down restart logs ps test clean

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
	docker compose logs -f cts-core

logs-hsm:
	docker compose logs -f hsm

logs-mysql:
	docker compose logs -f mysql

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
	docker compose down -v
	@echo "WARNING: This will delete all data!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ]
	rm -rf volumes/mysql-data/*
	rm -rf volumes/hsm-tokens/*

# Shell в контейнерах
shell-core:
	docker compose exec cts-core /bin/sh

shell-hsm:
	docker compose exec hsm /bin/sh

shell-mysql:
	docker compose exec mysql mysql -udevuser -pdevpass123 ct_system

# Помощь
help:
	@echo "Available commands:"
	@echo "  make up          - Start all services"
	@echo "  make down        - Stop all services"
	@echo "  make logs        - View all logs"
	@echo "  make logs-core   - View CTS-Core logs"
	@echo "  make ps          - Show service status"
	@echo "  make test        - Run CTS-Core tests"
	@echo "  make test-hsm    - Run HSM integration tests"
	@echo "  make build       - Rebuild Docker images"
	@echo "  make clean       - Remove all data (DANGER!)"
```

**Использование:**
```bash
cd /home/dev/ct-system
make up         # Запустить
make logs-core  # Смотреть логи CTS-Core
make test       # Запустить тесты
make down       # Остановить
```

---

## 📝 ПЛАН МИГРАЦИИ

### Шаг 1: Подготовка структуры ✅ ВЫПОЛНЕНО

```bash
# ✅ Директория создана
# ✅ Проекты скопированы в services/ (cts-core, hsm-service, trader-daemon, mysql, web-ui-go)
# ✅ Git инициализирован в корне
# ✅ Каждый сервис сохранил свой .git/

# Осталось сделать:
# 1. Создать .gitignore в корне (если нет)
cd /home/dev/docker/ct-system
cat > .gitignore << 'EOF'
# Volumes и данные
volumes/
.env
*.log

# Сервисы - у них свой git
services/

# Исключения: разрешить .env.example
!.env.example
EOF

# 2. Создать volumes директории
mkdir -p volumes/{mysql-data,hsm-tokens}
touch volumes/.gitkeep
```

### Шаг 2: Создать docker-compose.yml (10 минут)

Скопировать содержимое из секции "DOCKER COMPOSE ФАЙЛ" выше.

### Шаг 3: Создать .env файл (2 минуты)

```bash
cat > /home/dev/ct-system/.env << 'EOF'
# MySQL
MYSQL_ROOT_PASSWORD=devroot123
MYSQL_DATABASE=ct_system
MYSQL_USER=devuser
MYSQL_PASSWORD=devpass123

# Timezone
TZ=Europe/Moscow
EOF
```

### Шаг 4: Создать Makefile (5 минут)

Скопировать содержимое из секции "MAKEFILE ДЛЯ УПРАВЛЕНИЯ" выше.

### Шаг 5: Проверить Dockerfiles (10 минут)

**TODO для AI:** Проверить существуют ли Dockerfiles в:
- [x] `services/cts-core/Dockerfile` - уже есть
- [ ] `services/hsm-service/Dockerfile` - проверить
- [ ] `services/trader-daemon/Dockerfile` - проверить

### Шаг 6: Адаптировать конфиги (15 минут)

**CTS-Core:** Убедиться что `conf/config.yaml` использует:
```yaml
mysql:
  host: "mysql"  # Имя контейнера
  
hsm:
  url: "https://hsm:8443"  # Имя контейнера
```

**HSM:** Проверить `config.yaml` - возможно нужны изменения для Docker

### Шаг 7: Первый запуск (10 минут)

```bash
cd /home/dev/ct-system

# Запустить только MySQL и HSM (без cts-core пока)
docker compose up -d mysql hsm

# Проверить логи
make logs-mysql
make logs-hsm

# Проверить health
docker compose ps

# Если всё ОК - запустить CTS-Core
docker compose up -d cts-core
make logs-core
```

### Шаг 8: Тестирование (10 минут)

```bash
# Проверить что все контейнеры работают
make ps

# Запустить тесты
make test

# Запустить HSM integration тесты
make test-hsm

# Проверить подключение к MySQL
make shell-mysql
# Внутри: SHOW TABLES;
```

---

## 🔧 TROUBLESHOOTING

### Проблема: Symlinks не работают

**Решение:** Использовать полные пути или скопировать репозитории:
```bash
cp -r /home/dev/docker/cts-core /home/dev/ct-system/services/
```

### Проблема: Порты заняты

**Проверить:**
```bash
sudo lsof -i :3306  # MySQL
sudo lsof -i :8443  # HSM
sudo lsof -i :8080  # CTS-Core
```

**Решение:** Остановить существующие сервисы или изменить порты в docker-compose.yml

### Проблема: MySQL не инициализируется

**Решение:**
```bash
# Удалить старые данные
make clean

# Запустить заново
make up
```

---

## ❓ ВОПРОСЫ ДЛЯ УТОЧНЕНИЯ

1. ✅ **Структура директорий:** Согласны с новой организацией?
2. ⏳ **Dockerfiles:** Нужно проверить есть ли у HSM и daemon2
3. ⏳ **Конфиги:** Нужно проверить пути в config.yaml всех сервисов
4. ⏳ **Сертификаты:** Как организованы PKI сертификаты сейчас?
5. ⏳ **MySQL:** Есть ли уже запущенный MySQL или нужен новый?

---

## 🚀 СЛЕДУЮЩИЕ ШАГИ

### Сейчас (если вы AI помощник и получили этот документ):

1. **Спросить пользователя:**
   - "Готовы начать миграцию?"
   - "Нужно ли что-то уточнить в плане?"

2. **Если ответ ДА:**
   - Выполнить Шаг 1 (создать структуру)
   - Проверить существующие Dockerfiles
   - Создать недостающие файлы

3. **Если ответ НЕТ:**
   - Уточнить что нужно изменить в плане

### После миграции:

1. **Обновить DEVELOPMENT_PLAN.md:**
   - Добавить секцию про Docker Compose среду
   - Документировать как запускать тесты

2. **Создать README.md в корне:**
   - Как запустить систему
   - Как запустить тесты
   - Troubleshooting

3. **Перейти к Phase 1.4:**
   - State Management
   - Тестировать в Docker окружении

---

## 💾 СОХРАНЕНИЕ КОНТЕКСТА

**Файл содержит:**
- ✅ Полное описание целевой архитектуры
- ✅ Пошаговый план миграции
- ✅ Все необходимые конфиги и файлы
- ✅ Troubleshooting и FAQ
- ✅ Четкие следующие шаги

**Можно безопасно:**
- Закрыть VS Code
- Отключиться от проекта
- Вернуться позже

**При возвращении:**
- Открыть этот файл
- Дать AI и спросить "Продолжаем миграцию на Docker?"

```yaml
version: '3.8'

services:
  # 1. MySQL - общая БД для всех
  mysql:
    image: mysql:9
    container_name: dev-mysql
    environment:
      MYSQL_ROOT_PASSWORD: devroot123
      MYSQL_DATABASE: ct_system
      MYSQL_USER: devuser
      MYSQL_PASSWORD: devpass123
    volumes:
      - ./dev-data/mysql:/var/lib/mysql
      - ./cts-core/migrations:/docker-entrypoint-initdb.d:ro
    ports:
      - "3306:3306"  # Для доступа с хоста
    networks:
      - cts-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # 2. HSM Service
  hsm:
    build:
      context: ./other-sub-system/hsm-service
      dockerfile: Dockerfile
    container_name: dev-hsm
    volumes:
      - ./other-sub-system/hsm-service/config.yaml:/app/config.yaml:ro
      - ./other-sub-system/hsm-service/pki:/app/pki:ro
      - ./dev-data/hsm-tokens:/app/data/tokens
    ports:
      - "8443:8443"  # HSM API
    networks:
      - cts-net
    healthcheck:
      test: ["CMD", "curl", "-k", "https://localhost:8443/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  # 3. CTS-Core (оркестратор)
  cts-core:
    build:
      context: ./cts-core
      dockerfile: Dockerfile
    container_name: dev-cts-core
    depends_on:
      mysql:
        condition: service_healthy
      hsm:
        condition: service_healthy
    volumes:
      - ./cts-core/conf:/app/conf:ro
      - ./cts-core/pki:/app/pki:ro
      - ./dev-data/logs/cts-core:/app/logs
      - ./dev-data/state:/app/state
    environment:
      - TZ=Europe/Moscow
      - CTS_ENVIRONMENT=development
      - CTS_MYSQL_HOST=mysql
      - CTS_MYSQL_PASSWORD=devpass123
    ports:
      - "8080:8080"  # REST API (Phase 1.5+)
      - "8081:8081"  # WebSocket (Phase 2+)
    networks:
      - cts-net
    restart: unless-stopped

  # 4. Trader 1 (Binance simulator)
  trader-1:
    build:
      context: ./other-sub-system/daemon2
      dockerfile: Dockerfile
    container_name: dev-trader-1
    depends_on:
      - cts-core
      - hsm
    volumes:
      - ./other-sub-system/daemon2/conf:/app/conf:ro
      - ./other-sub-system/daemon2/pki:/app/pki:ro
      - ./dev-data/logs/trader-1:/app/logs
    environment:
      - TRADER_ID=trader-1
      - TRADER_NAME=Binance-Trader-1
      - CTS_CORE_URL=https://cts-core:8080
      - HSM_URL=https://hsm:8443
    networks:
      - cts-net
    restart: unless-stopped

  # 5. Trader 2 (KuCoin simulator)
  trader-2:
    build:
      context: ./other-sub-system/daemon2
      dockerfile: Dockerfile
    container_name: dev-trader-2
    depends_on:
      - cts-core
      - hsm
    volumes:
      - ./other-sub-system/daemon2/conf:/app/conf:ro
      - ./other-sub-system/daemon2/pki:/app/pki:ro
      - ./dev-data/logs/trader-2:/app/logs
    environment:
      - TRADER_ID=trader-2
      - TRADER_NAME=KuCoin-Trader-1
      - CTS_CORE_URL=https://cts-core:8080
      - HSM_URL=https://hsm:8443
    networks:
      - cts-net
    restart: unless-stopped

  # 6. Trader 3 (Bybit simulator)
  trader-3:
    build:
      context: ./other-sub-system/daemon2
      dockerfile: Dockerfile
    container_name: dev-trader-3
    depends_on:
      - cts-core
      - hsm
    volumes:
      - ./other-sub-system/daemon2/conf:/app/conf:ro
      - ./other-sub-system/daemon2/pki:/app/pki:ro
      - ./dev-data/logs/trader-3:/app/logs
    environment:
      - TRADER_ID=trader-3
      - TRADER_NAME=Bybit-Trader-1
      - CTS_CORE_URL=https://cts-core:8080
      - HSM_URL=https://hsm:8443
    networks:
      - cts-net
    restart: unless-stopped

  # 7. Web UI (опционально, Phase 4+)
  # www-go:
  #   build:
  #     context: ./other-sub-system/www-go
  #     dockerfile: Dockerfile
  #   container_name: dev-www
  #   ports:
  #     - "443:443"
  #   networks:
  #     - cts-net

networks:
  cts-net:
    driver: bridge
    name: cts-dev-network

volumes:
  mysql-data:
  hsm-tokens:
```

---

## План миграции

### Этап 1: Подготовка (30 минут)

1. **Создать структуру:**
   ```bash
   cd /home/dev/docker
   
   # Создать директории для данных
   mkdir -p dev-data/{mysql,logs/{cts-core,trader-1,trader-2,trader-3},state,hsm-tokens}
   
   # Создать .gitignore для dev-data
   echo "dev-data/" >> .gitignore
   ```

2. **Создать docker-compose.dev.yml** в корне `/home/dev/docker/`

3. **Создать .env.dev** с переменными:
   ```env
   # MySQL
   MYSQL_ROOT_PASSWORD=devroot123
   MYSQL_DATABASE=ct_system
   MYSQL_USER=devuser
   MYSQL_PASSWORD=devpass123
   
   # Timezone
   TZ=Europe/Moscow
   
   # Ports
   MYSQL_PORT=3306
   HSM_PORT=8443
   CTS_CORE_PORT=8080
   ```

### Этап 2: Проверка Dockerfiles (1 час)

1. **CTS-Core Dockerfile** - уже есть ✅
2. **HSM Service Dockerfile** - проверить существует ли
3. **Daemon2 (Trader) Dockerfile** - создать если нет

**Для daemon2 (если нет):**
```dockerfile
# other-sub-system/daemon2/Dockerfile
FROM golang:1.24.9-alpine AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o trader ./cmd/daemon

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
COPY --from=builder /build/trader .
CMD ["./trader"]
```

### Этап 3: Адаптация конфигов (1 час)

**Проблема:** Конфиги в проектах используют localhost, нужны имена контейнеров.

**Решение:** Environment variables override

**cts-core/conf/config.yaml:**
```yaml
mysql:
  host: "mysql"  # Имя сервиса в docker-compose
  port: 3306
  # или через ENV: ${CTS_MYSQL_HOST:-localhost}

hsm:
  url: "https://hsm:8443"  # Имя сервиса
```

**daemon2/conf/config.yaml:**
```yaml
cts_core:
  url: "https://cts-core:8080"
  
hsm:
  url: "https://hsm:8443"
```

**Альтернатива:** Создать отдельные `config.docker.yaml` для dev

### Этап 4: Сертификаты (30 минут)

**Проблема:** PKI сертификаты сейчас в каждом проекте

**Варианты:**
1. **Оставить как есть** - каждый проект монтирует свои `pki/`
2. **Shared volume** - общая директория `dev-data/certs/`
3. **Generate on startup** - init container генерирует сертификаты

**Рекомендую:** Вариант 1 (оставить как есть), проще всего

### Этап 5: Миграции БД (15 минут)

**Автоматическая инициализация:**
```yaml
mysql:
  volumes:
    - ./cts-core/migrations:/docker-entrypoint-initdb.d:ro
```

MySQL автоматически выполнит `.sql` файлы при первом запуске.

### Этап 6: Запуск и тестирование (1 час)

```bash
cd /home/dev/docker

# Запуск всех сервисов
docker compose -f docker-compose.dev.yml up -d

# Проверка логов
docker compose -f docker-compose.dev.yml logs -f cts-core
docker compose -f docker-compose.dev.yml logs -f hsm
docker compose -f docker-compose.dev.yml logs -f trader-1

# Проверка health
docker compose -f docker-compose.dev.yml ps

# Остановка
docker compose -f docker-compose.dev.yml down

# Остановка + очистка volumes
docker compose -f docker-compose.dev.yml down -v
```

---

## VS Code Integration

### .vscode/tasks.json (для всех проектов)

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Docker: Start DEV Environment",
      "type": "shell",
      "command": "docker compose -f ../docker-compose.dev.yml up -d",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "shared"
      }
    },
    {
      "label": "Docker: Stop DEV Environment",
      "type": "shell",
      "command": "docker compose -f ../docker-compose.dev.yml down",
      "problemMatcher": []
    },
    {
      "label": "Docker: View CTS-Core Logs",
      "type": "shell",
      "command": "docker compose -f ../docker-compose.dev.yml logs -f cts-core",
      "problemMatcher": []
    },
    {
      "label": "Docker: Restart CTS-Core",
      "type": "shell",
      "command": "docker compose -f ../docker-compose.dev.yml restart cts-core",
      "problemMatcher": []
    }
  ]
}
```

### Multi-root Workspace (РЕКОМЕНДУЮ)

Создать `/home/dev/docker/cts-dev.code-workspace`:

```json
{
  "folders": [
    {
      "path": "cts-core",
      "name": "🎛️ CTS-Core"
    },
    {
      "path": "other-sub-system/hsm-service",
      "name": "🔐 HSM Service"
    },
    {
      "path": "other-sub-system/daemon2",
      "name": "🤖 Trader Daemon"
    },
    {
      "path": "other-sub-system/www-go",
      "name": "🌐 Web UI"
    }
  ],
  "settings": {
    "go.gopath": "${workspaceFolder}",
    "go.inferGopath": true,
    "files.exclude": {
      "**/dev-data": true,
      "**/.git": false
    }
  },
  "extensions": {
    "recommendations": [
      "golang.go",
      "ms-azuretools.vscode-docker"
    ]
  }
}
```

**Использование:**
```bash
code /home/dev/docker/cts-dev.code-workspace
```

Теперь VS Code покажет все проекты в одном окне!

---

## Тестирование с Docker Compose

### Integration Tests

**Запуск тестов внутри контейнеров:**

```bash
# 1. Запустить окружение
docker compose -f docker-compose.dev.yml up -d

# 2. Дождаться готовности
docker compose -f docker-compose.dev.yml exec cts-core /bin/sh -c "until nc -z mysql 3306; do sleep 1; done"

# 3. Запустить тесты CTS-Core
docker compose -f docker-compose.dev.yml exec cts-core go test -v ./...

# 4. Запустить HSM integration tests
docker compose -f docker-compose.dev.yml exec cts-core go test -v -tags=integration ./internal/hsm/...

# 5. Проверить логи
docker compose -f docker-compose.dev.yml logs cts-core
```

### Makefile для удобства

**Создать `/home/dev/docker/Makefile.dev:**

```makefile
.PHONY: up down restart logs test clean

up:
	docker compose -f docker-compose.dev.yml up -d

down:
	docker compose -f docker-compose.dev.yml down

restart:
	docker compose -f docker-compose.dev.yml restart

logs:
	docker compose -f docker-compose.dev.yml logs -f

logs-core:
	docker compose -f docker-compose.dev.yml logs -f cts-core

logs-hsm:
	docker compose -f docker-compose.dev.yml logs -f hsm

test:
	@echo "Running CTS-Core tests..."
	docker compose -f docker-compose.dev.yml exec cts-core go test -v ./...

test-hsm:
	@echo "Running HSM integration tests..."
	docker compose -f docker-compose.dev.yml exec cts-core go test -v -tags=integration ./internal/hsm/...

ps:
	docker compose -f docker-compose.dev.yml ps

clean:
	docker compose -f docker-compose.dev.yml down -v
	rm -rf dev-data/mysql/*
	rm -rf dev-data/logs/*

rebuild:
	docker compose -f docker-compose.dev.yml build --no-cache

shell-core:
	docker compose -f docker-compose.dev.yml exec cts-core /bin/sh

shell-trader:
	docker compose -f docker-compose.dev.yml exec trader-1 /bin/sh
```

**Использование:**
```bash
make -f Makefile.dev up
make -f Makefile.dev logs-core
make -f Makefile.dev test
make -f Makefile.dev down
```

---

## Управление сертификатами

### Вариант 1: Монтировать из проектов (текущий)

```yaml
cts-core:
  volumes:
    - ./cts-core/pki:/app/pki:ro

trader-1:
  volumes:
    - ./other-sub-system/daemon2/pki:/app/pki:ro
```

**Проблема:** Если пути к сертификатам разные в каждом проекте

### Вариант 2: Shared volume (если нужна синхронизация)

```yaml
services:
  cert-init:
    image: alpine
    volumes:
      - certs:/certs
    command: |
      sh -c "
        mkdir -p /certs/{ca,client,server} &&
        cp /source/ca/* /certs/ca/ &&
        cp /source/client/* /certs/client/
      "
    volumes:
      - ./cts-core/pki:/source:ro
      - certs:/certs

  cts-core:
    depends_on:
      - cert-init
    volumes:
      - certs:/app/pki:ro

volumes:
  certs:
```

---

## Git Strategy

### Важно: НЕ коммитить в git проектов

**Добавить в каждый проект `.gitignore`:**

```gitignore
# CTS-Core specific
docker-compose.dev.yml  # Только если в корне проекта
.env.dev

# HSM Service specific  
docker-compose.dev.yml
.env.dev

# Daemon2 specific
docker-compose.dev.yml
.env.dev
```

**Общий `.gitignore` в корне `/home/dev/docker/`:**

```gitignore
# Dev environment data
dev-data/
docker-compose.dev.yml  # Если хотите держать локально
.env.dev
Makefile.dev
README-DEV.md

# VS Code workspace
*.code-workspace
```

### Git submodules (опционально)

Если хотите версионировать связь проектов:

```bash
cd /home/dev/docker
git init
git submodule add <url> cts-core
git submodule add <url> other-sub-system/hsm-service
git submodule add <url> other-sub-system/daemon2
```

**Но:** Это усложняет, рекомендую пока НЕ делать

---

## Troubleshooting

### Проблема: Контейнеры не видят друг друга

**Решение:**
```bash
docker compose -f docker-compose.dev.yml ps
docker network inspect cts-dev-network
```

Проверить что все сервисы в одной сети `cts-net`

### Проблема: MySQL не инициализируется

**Решение:**
```bash
docker compose -f docker-compose.dev.yml down -v  # Удалить volumes
docker compose -f docker-compose.dev.yml up -d mysql
docker compose -f docker-compose.dev.yml logs mysql
```

### Проблема: HSM сертификаты не работают

**Решение:**
```bash
# Проверить монтирование
docker compose -f docker-compose.dev.yml exec hsm ls -la /app/pki

# Проверить пути в конфиге
docker compose -f docker-compose.dev.yml exec hsm cat /app/config.yaml
```

### Проблема: Traders не подключаются к CTS-Core

**Причина:** CTS-Core еще не готов (Phase 1.5 REST API)

**Решение:** Пока оставить traders commented в docker-compose.dev.yml, включить после Phase 1.5+

---

## Roadmap

### Phase 1 (Foundation) - Текущее
- ✅ MySQL
- ✅ HSM Service  
- ✅ CTS-Core (без WebSocket пока)
- ⏸️ Traders (ждут Phase 2 WebSocket)

### Phase 2 (Core Features)
- ✅ Добавить Traders после реализации WebSocket в CTS-Core
- ✅ Тестировать Session Manager
- ✅ Тестировать Heartbeat

### Phase 3 (Business Logic)
- ✅ Тестировать Task Scheduler
- ✅ Тестировать Load Balancing
- ✅ 3 Traders симулируют разные биржи

### Phase 4 (Integration)
- ✅ Добавить www-go (Web UI)
- ✅ End-to-end тесты

---

## Итоговая команда для запуска

```bash
# Из корня /home/dev/docker/
docker compose -f docker-compose.dev.yml up -d

# Проверка
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml logs -f cts-core

# Остановка
docker compose -f docker-compose.dev.yml down
```

---

## Вопросы для уточнения

1. **MySQL:** Есть ли уже docker-compose для MySQL или поднимать новый?
2. **HSM Service:** Есть ли Dockerfile? Где config.yaml?
3. **Daemon2:** Есть ли Dockerfile? Как конфигурировать разные TRADER_ID?
4. **Сертификаты:** Можно ли использовать одни и те же для dev или нужны разные?
5. **VS Code:** Хотите multi-root workspace или держать проекты отдельно?

---

## Следующий шаг

Когда будете готовы:
1. Я проверю существующие Dockerfiles (HSM, daemon2)
2. Создам docker-compose.dev.yml с учетом реальных конфигов
3. Настроим VS Code workspace
4. Запустим и протестируем

**Готовы начать?** Дайте знать и я начну с проверки HSM Service и daemon2.
