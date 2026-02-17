# CT-System — Общий план разработки

> **Версия**: 1.0  
> **Дата**: 2026-02-01  
> **Статус**: Docker окружение готово | Фокус на стандартизации

---

## 📊 Текущее состояние системы

### ✅ Что работает

| Компонент | Статус | Версия | Healthcheck |
|-----------|--------|--------|-------------|
| **MySQL** | ✅ Running | 9.0 | ✅ Healthy |
| **HSM Service** | ✅ Running | Production-ready | ✅ Healthy |
| **CTS-Core** | ✅ Running | Phase 1.3 Complete | ✅ Healthy |
| **Web UI** | ✅ Running | Operational | ✅ Healthy |
| **Trader-1** | ✅ Running | Phase 1 Complete | ✅ Healthy |
| **Docker Compose** | ✅ Ready | All services orchestrated | ✅ All healthy |

### 📍 Прогресс по фазам

**CTS-Core:**
- ✅ Phase 0: Database schema (18 таблиц)
- ✅ Phase 1.1: Project setup + config + logger
- ✅ Phase 1.2: MySQL pool + repositories (8 repos)
- ✅ Phase 1.3: HSM client (dual context: trading + 2FA)
- 🔴 **Phase 1.4**: State management (в процессе)
- ⏳ Phase 1.5: Basic REST API
- ⏳ Phase 2: WebSocket + Session manager
- ⏳ Phase 3: Task scheduler + Load balancing
- ⏳ Phase 4: Full integration + Trade results

**Trader Daemon:**
- ✅ Phase 1: Фундамент (структура, типы, базовая инфраструктура)
- ⏳ Phase 2: WebSocket client к CTS-Core
- ⏳ Phase 3: Order book + Pub/Sub
- ⏳ Phase 4+: Task management, Monitor/Trader roles

**HSM Service:**
- ✅ Production-ready (mTLS, key rotation, ACL, monitoring)
- 🟡 Предложения: объединение CLI, multi-slot architecture

**Web UI (Go):**
- ✅ Recovered core: authentication, users/groups, exchanges, exchange accounts
- 🔴 Missing in recovered code: positions, market analysis, daemon, coins
- ⏳ Phase 4.1 analytics: not implemented in recovered code
- 🔴 Миграция логирования на slog (обязательно, равнение на hsm-service)

---

## 🎯 ПРИОРИТЕТЫ РАЗРАБОТКИ

### Priority 1: Стандартизация (2-3 дня) 🔴

**Проблема:** Разные подходы к критически важным аспектам системы создают технический долг и усложняют поддержку.

#### 1.1. Унификация логирования (2-3 дня) 🔴

**КЛЮЧЕВАЯ ПРОБЛЕМА:** Разделенные подходы к логированию затрудняют отладку в Docker и мониторинг

**Текущая ситуация:**

| Сервис | Библиотека | Формат | Stdout | Файл | Ротация | docker logs |
|--------|-----------|--------|--------|------|---------|------------|
| HSM | ✅ slog | ✅ JSON | ✅ | ✅ | ✅ lumberjack | ✅ Работает |
| CTS-Core | ✅ slog | ❌ Text | ❌ | ✅ | ❌ Custom | ❌ Нет логов |
| Trader | ✅ slog | ❌ Text | ❌ | ✅ | ❌ Custom | ❌ Нет логов |
| Web UI | ❌ zerolog | ✅ JSON | ✅ | ✅ | ✅ lumberjack | ✅ Работает |

**Основной дефект:** `docker logs ct-system-cts-core-1` и `docker logs ct-system-trader-daemon-1` **НЕ показывают логи**, потому что логирующие потоки идут только в файл!

**Детальный анализ:** [LOGGING_ANALYSIS_DETAILED.md](LOGGING_ANALYSIS_DETAILED.md) (62 строк, чек-листы, примеры)

### Требуемые изменения по сервисам

#### CTS-Core (1 день)
```
Priority: HIGH
Impact: docker logs станут видны
Effort: 1-2 дня

[ ] Добавить os.Stdout в MultiWriter (logger.go:45)
    - Change: w := errorRotated  →  w := io.MultiWriter(os.Stdout, errorRotated)
    
[ ] Переключить на JSON формат (logger.go:70)
    - Current: &plainTextHandler{...}
    - New: slog.NewJSONHandler(w, &slog.HandlerOptions{Level: logLevel})
    
[ ] Заменить custom rotatedFile на lumberjack (logger.go:25-60)
    - Run: go get github.com/natefinch/lumberjack
    - Delete: struct rotatedFile (60 lines)
    - Add: &lumberjack.Logger{MaxSize: maxFileSizeMB, MaxBackups: 10, MaxAge: 30, Compress: true}
    
[ ] Тестирование:
    - docker-compose up cts-core-1
    - docker logs ct-system-cts-core-1 | head -20
    - Expected: JSON strings with module, level, etc.
```

**Files to modify:**
- [services/cts-core/internal/logger/logger.go](services/cts-core/internal/logger/logger.go)
- `go.mod` (add lumberjack)

**Reference implementation:** [services/hsm-service/internal/server/logger.go](services/hsm-service/internal/server/logger.go)

---

#### Trader Daemon (1 день)
```
Priority: HIGH
Impact: docker logs станут видны
Effort: 1 day (identical changes to CTS-Core)

[ ] Same as CTS-Core:
    - os.Stdout in MultiWriter
    - JSON format (slog.NewJSONHandler)
    - Replace rotatedFile with lumberjack

[ ] File to modify:
    - services/trader-daemon/internal/logger/logger.go
    
[ ] Difference from CTS-Core:
    - Trader has Trade logger module (use same pattern)
    - Both modules (main + trade) write to single file
```

**Files to modify:**
- [services/trader-daemon/internal/logger/logger.go](services/trader-daemon/internal/logger/logger.go)

---

#### Web UI (2-3 дня)
```
Priority: HIGH
Complexity: Medium (library migration + stream splitting)
Impact: Unified with other services + new access log analytics

[ ] PHASE 1: Migration from zerolog → slog (1 day)
    [ ] Remove zerolog from go.mod
    [ ] Replace 'import "github.com/rs/zerolog"' with 'import "log/slog"'
    [ ] Update all logger.Get() calls to slog.Default() / slog.With("module", "...")
    [ ] Test: make test (all tests must pass)

[ ] PHASE 2: Implement Access Log Splitting (1-2 days)
    [ ] Create internal/logger/access_logger.go
        - Separate slog.Logger for HTTP request logging
        - Format: method, path, status, duration_ms, client_ip, user_id
        
    [ ] Create internal/logger/error_logger.go
        - Main slog.Logger for app errors
        - Format: level, message, module, error, context
        
    [ ] Create internal/middleware/access_log_middleware.go
        - Gin middleware to capture all HTTP requests
        - Log method, path, status, latency, IP
        
    [ ] Update lumberjack config:
        - access.log: 50MB max, keep 10, 7 days
        - error.log: 100MB max, keep 5, 30 days
        
    [ ] Test:
        - docker logs | grep "HTTP\|error"
        - Check /var/log/web-ui/ has both access.log and error.log

[ ] Configuration:
    - logging:
        level: "info"
        dir: "/var/log/web-ui"
        format: "json"
        max_file_size_mb: 100
        access_log:
          enabled: true
          max_file_size_mb: 50
          max_backups: 10
          max_age_days: 7

[ ] Files to create/modify:
    - services/web-ui-go/internal/logger/logger.go (REWRITE)
    - services/web-ui-go/internal/logger/access_logger.go (NEW)
    - services/web-ui-go/internal/logger/error_logger.go (NEW)
    - services/web-ui-go/internal/middleware/access_log.go (NEW)
    - services/web-ui-go/conf/config.yaml (update logging section)
```

**Detailed guide:** See [services/web-ui-go/DEVELOPMENT_PLAN.md](services/web-ui-go/DEVELOPMENT_PLAN.md) Section 2 "КРИТИЧНО: Унификация логирования"

---

#### HSM Service (optional improvements)
```
Status: Updated ✅
Priority: LOW (improvements only, not blocking)

[x] Split audit, access, and error logs with rotation + JSON
    - audit.log, access.log, error.log with lumberjack
    - audit/access can mirror to stdout; error can mirror debug

[x] Request tracking in audit/access/error logs
    - request_id header X-Request-ID
    - status/result/error_code, key_id, audit context

[x] Startup validation of log paths
    - fail fast if log dir is not writable
    - default paths and env overrides via config

[x] Docs + integration/e2e updates
    - log mounts in docker-compose and tests
    - references in monitoring/troubleshooting

[x] Graceful shutdown + panic recovery
    - SIGTERM/SIGINT -> Shutdown(ctx)
    - CloseLogger() on exit
    - recovery middleware logs stack in error.log
```

---

### 📊 Unified Logging Standard Summary

**Technology Stack:**
- **Library:** `log/slog` (Go stdlib 1.21+, no external deps)
- **Format:** JSON (for log aggregation tools)
- **Output:** MultiWriter(os.Stdout, logfile)
- **Rotation:** lumberjack.Logger (size + age + compress + cleanup)
- **Modularity:** slog.With("module", "name") for component tracking

**Log Files (per service):**
```
/var/log/cts-core/
  └── error.log*          # All logs (JSON format)

/var/log/trader-daemon/
  └── daemon.log*         # All logs (JSON format)

/var/log/web-ui-go/
  ├── access.log*         # HTTP requests only (JSON, 50MB limit)
  └── error.log*          # Errors + events (JSON, 100MB limit)

/var/log/hsm-service/
    ├── audit.log*          # Audit logs (JSON format)
    ├── access.log*         # HTTP access logs (JSON format)
    └── error.log*          # Error/system logs (JSON format)
```

**Where \* means rotated files:**
```
error.log              # current
error.log.1            # backup 1 (if rotated)
error.log.1.gz         # compressed
error.log.2.gz
error.log.3.gz
```

**Benefits:**
- ✅ All logs visible in `docker logs <service>`
- ✅ JSON format → easy to parse in ELK/Loki/Grafana
- ✅ Automatic rotation, compression, and cleanup
- ✅ No external logging dependencies
- ✅ Web UI access logs for analytics
- ✅ Consistent across all 4 services

---

**Результат:**
- Все логи видны в `docker logs <service>`
- Единый JSON формат для ELK/Loki/Grafana
- Файлы с ротацией для долгосрочного хранения
- Нет внешних зависимостей (только stdlib + lumberjack)
- Web UI: разделенные логи (access.log + error.log) для аналитики и отладки

**Файлы:**
- `/home/dev/docker/ct-system/LOGGING_ANALYSIS.md` (подробный анализ)
- `services/cts-core/internal/logger/logger.go`
- `services/trader-daemon/internal/logger/logger.go`
- `services/web-ui-go/internal/logger/logger.go` (с access/error разделением)
- `services/web-ui-go/internal/middleware/request_logging.go` (новый файл для HTTP логирования)

---

#### 1.2. Унификация конфигурации (0.5 дня)

**Текущая ситуация:**

| Сервис | Формат | Env override | Validation |
|--------|--------|--------------|------------|
| HSM | YAML | ✅ | ✅ |
| CTS-Core | YAML | ✅ | ✅ |
| Trader | INI | ❌ | ⚠️ |
| Web UI | YAML | ✅ | ✅ |

**Проблема:**
- Trader использует INI (отличается от остальных)
- Inconsistent ENV variable support

**Решение:**
- Trader: мигрировать на YAML (как CTS-Core и HSM)
- Стандартизировать ENV override pattern

**Задачи:**
```
[ ] Trader: config.ini → config.yaml
[ ] Trader: Добавить поддержку ENV variables (${VAR:-default})
[ ] Проверить: все сервисы читают ENV из docker-compose.yml
[ ] Документация: Обновить README.md с примерами конфигов
```

---

#### 1.3. Стандартизация healthchecks (0.5 дня)

**Текущая ситуация:**
- ✅ HSM: `/health` endpoint (HTTPS)
- ✅ MySQL: `mysqladmin ping`
- ⚠️ CTS-Core: healthcheck есть, но deadlock при старте
- ⚠️ Trader: healthcheck отсутствует
- ✅ Web UI: HTTP endpoint

**Решение:**
- Все HTTP сервисы: `/health` endpoint (GET)
- Стандартный формат ответа:
  ```json
  {
    "status": "healthy",
    "service": "cts-core",
    "version": "1.4.0",
    "uptime": "2h34m12s",
    "dependencies": {
      "mysql": "connected",
      "hsm": "connected"
    }
  }
  ```

**Задачи:**
```
[ ] CTS-Core: Исправить deadlock при старте (см. Phase 1.4)
[ ] CTS-Core: Улучшить /health (добавить dependencies check)
[ ] Trader: Добавить /health endpoint на отдельном порту
[ ] Docker-compose: Обновить healthcheck для всех сервисов
[ ] Тестирование: make health-check (проверка всех сервисов)
```

---

#### 1.4. Документация и CI/CD подготовка (1 день)

**Задачи:**
```
[ ] README.md: Обновить с учетом стандартизации
[ ] ARCHITECTURE.md: Добавить диаграммы взаимодействия сервисов
[ ] API_SPECIFICATION.md: Унифицировать форматы всех API
[ ] .github/workflows/: Подготовить CI pipeline (lint, test, build)
[ ] Makefile: Добавить targets для стандартизации (make lint-all, make test-all)
```

---

### Priority 2: Завершение Phase 1 CTS-Core (5-7 дней) 🟡

#### 2.1. Phase 1.4: State Management (2 дня)

**Текущая проблема:**
- Deadlock при старте CTS-Core (select без cases)
- State persistence не реализован

**Задачи:**
```
[ ] Реализовать StateManager (load/save daemon.state)
[ ] Исправить deadlock в main.go
[ ] Добавить graceful shutdown (SIGTERM, SIGINT)
[ ] State format: JSON с версионированием
[ ] Atomic writes (write → rename)
[ ] Tests: state save/load/recovery
[ ] Документация: guides/phase_1_4_state_management.md
```

**Файлы:**
- `services/cts-core/internal/state/state.go`
- `services/cts-core/cmd/cts-core/main.go`

---

#### 2.2. Phase 1.5: Basic REST API (3 дня)

**Scope:**
- GET `/health` - healthcheck
- GET `/api/v1/traders` - список подключенных трейдеров
- GET `/api/v1/traders/{id}` - информация о трейдере
- GET `/api/v1/stats` - общая статистика
- GET `/api/v1/tasks` - текущие задачи

**Задачи:**
```
[ ] Создать internal/api/server.go (HTTP server setup)
[ ] Создать internal/api/rest/ handlers
[ ] Middleware: logging, recovery, CORS
[ ] Tests: unit + integration (httptest)
[ ] OpenAPI spec (Swagger)
[ ] Rate limiting (базовый)
[ ] Документация: API_SPECIFICATION.md
```

**Зависимости:**
- State Manager (Phase 1.4)
- MySQL repositories (Phase 1.2) ✅

---

### Priority 3: WebSocket Infrastructure (7-10 дней) 🟢

#### 3.1. Phase 2.1: WebSocket Server для Traders (3 дня)

**Протокол:**
```json
// Trader → CTS-Core
{
  "type": "register",
  "trader_id": "trader-1",
  "exchange": "binance",
  "capabilities": ["spot", "futures"],
  "version": "1.0.0"
}

// CTS-Core → Trader
{
  "type": "task",
  "task_id": "task-123",
  "task_type": "arbitrage_cross",
  "params": {...}
}
```

**Задачи:**
```
[ ] internal/api/ws/trader_handler.go
[ ] Connection pooling + heartbeat (30s)
[ ] Message routing (task assignment)
[ ] Reconnection handling
[ ] Tests: WS integration tests
```

---

#### 3.2. Phase 2.2: Session Manager (2 дня)

**Функции:**
- Registration: Trader подключается
- Hybrid registration: MySQL (persistent) + memory (active)
- Heartbeat tracking (disconnect after 3 missed)
- Resource limits (max connections)

**Задачи:**
```
[ ] internal/session/manager.go
[ ] internal/session/trader.go
[ ] internal/session/heartbeat.go
[ ] DB integration (trader_session table)
[ ] Metrics: active_traders, heartbeat_latency
[ ] Tests: session lifecycle
```

---

#### 3.3. Phase 2.3: Task Scheduler (3 дня)

**Алгоритм:**
- Scoring: latency (50%) + workload (30%) + history (20%)
- Load balancing между traders
- Task retry на failure
- Priority queue

**Задачи:**
```
[ ] internal/scheduler/scheduler.go
[ ] internal/scheduler/assignment.go (scoring)
[ ] internal/scheduler/latency.go
[ ] DB integration (scheduler_task table)
[ ] Tests: load balancing, retries
```

---

### Priority 4: Trader Daemon Phase 2 (5-7 дней) 🟢

#### 4.1. WebSocket Client к CTS-Core (2 дня)

**Задачи:**
```
[ ] internal/core/ws/client.go (WS client)
[ ] Reconnection с exponential backoff
[ ] Message handlers (register, task, heartbeat)
[ ] Integration с существующей структурой
[ ] Tests: WS client lifecycle
```

---

#### 4.2. HSM Integration в Trader (2 дня)

**Задачи:**
```
[ ] Интеграция HSM client (аналогично CTS-Core Phase 1.3)
[ ] Credential decryption flow
[ ] Secure storage encrypted credentials
[ ] Tests: HSM integration
```

---

#### 4.3. Task Execution Framework (2 дня)

**Задачи:**
```
[ ] internal/task/executor.go
[ ] Task types: arbitrage_cross, triangular, limit_market
[ ] Result reporting к CTS-Core
[ ] Error handling + retries
[ ] Tests: task execution
```

---

### Priority 5: HSM Service Enhancements (3-5 дней) ⚪

**Опционально (low priority):**

```
[x] Объединение create-kek в hsm-admin (CLI unification, DONE v2.0.0)
[ ] Multi-slot architecture (изоляция контекстов)
[ ] Audit API (REST endpoint для аудита)
[ ] Key escrow (split knowledge для recovery)
[ ] Encrypted backup automation
```

**Статус:** HSM уже production-ready, улучшения можно отложить

---

### Priority 6: Web UI Enhancements (5-7 дней) ⚪

**Опционально (после CTS-Core Phase 2 WebSocket):**

#### 6.1. WebSocket Integration (3 дня)

**Цель:** Real-time обновления данных в UI без перезагрузки страницы

**Задачи:**
```
[ ] WebSocket client в frontend (JavaScript)
[ ] Подключение к CTS-Core WS endpoint (Phase 2)
[ ] Real-time trader status updates
[ ] Real-time task assignment notifications
[ ] Live position P&L updates
[ ] System health monitoring dashboard
[ ] Tests: WS connection, reconnection, message handling
```

**Зависимости:**
- CTS-Core Phase 2 WebSocket server (admin endpoint) ✅ После Priority 3

---

#### 6.2. Live Price Feeds (2 дня)

**Цель:** Автоматическое обновление цен без ручного ввода

**Текущее состояние:**
- Phase 4.1: Manual price updates (`POST /positions_calc/ajax_update_price`)
- Phase 4.1: P&L calculations с текущими ценами

**Задачи:**
```
[ ] Integration с exchange APIs (Binance, KuCoin, Bybit)
[ ] Price caching (Redis опционально)
[ ] Auto-update prices every 5-10 seconds
[ ] Fallback на ручной ввод при API failures
[ ] Price history storage (для графиков)
[ ] Tests: API integration, price updates, error handling
```

**API Sources:**
- Binance: `wss://stream.binance.com:9443/ws`
- KuCoin: `wss://ws-api.kucoin.com/endpoint`
- Bybit: `wss://stream.bybit.com/v5/public/spot`

---

#### 6.3. Logging Migration на slog (1 день)

**Цель:** Единый подход к логированию во всей системе

**Текущее состояние:**
- Web UI использует `zerolog` (text format)
- Конфигурация: `logging.output: "both"` (stdout + file)
- ✅ Работает корректно, логи видны в docker logs

**Задачи:**
```
[ ] Заменить zerolog на log/slog
[ ] Переключить на JSON формат (slog.NewJSONHandler)
[ ] Использовать lumberjack для ротации (как в HSM)
[ ] Обновить internal/logger/logger.go
[ ] Обновить конфигурацию (logging.format: "json")
[ ] Удалить зависимость: github.com/rs/zerolog
[ ] Tests: logging initialization, format, rotation
[ ] Документация: обновить LOGGING.md
```

**Приоритет:** LOW (работает, но для единообразия желательно)

---

#### 6.4. Advanced Analytics Dashboard (2 дня)

**Текущее состояние:** Phase 4.1 API готов

**Задачи:**
```
[ ] Interactive charts (Chart.js или Plotly)
[ ] Portfolio performance timeline
[ ] P&L history graphs
[ ] Win/loss distribution
[ ] Symbol-based analytics
[ ] Export reports (CSV, PDF)
[ ] Tests: chart rendering, data accuracy
```

---

## 📅 Timeline (оценка)

```mermaid
gantt
    title CT-System Development Timeline
    dateFormat YYYY-MM-DD
    
    section Priority 1: Стандартизация
    Унификация логирования       :p1a, 2026-02-01, 1d
    Конфигурация + healthchecks  :p1b, after p1a, 1d
    Документация                 :p1c, after p1b, 1d
    
    section Priority 2: CTS-Core Phase 1
    Phase 1.4: State management  :p2a, after p1c, 2d
    Phase 1.5: REST API          :p2b, after p2a, 3d
    
    section Priority 3: WebSocket
    WS Server для Traders        :p3a, after p2b, 3d
    Session Manager              :p3b, after p3a, 2d
    Task Scheduler               :p3c, after p3b, 3d
    
    section Priority 4: Trader Phase 2
    WS Client                    :p4a, after p3a, 2d
    HSM Integration              :p4b, after p4a, 2d
    Task Execution               :p4c, after p4b, 2d
    
    section Priority 5: HSM (опционально)
    CLI unification              :p5a, after p4c, 2d
    Multi-slot architecture      :p5b, after p5a, 3d
    
    section Priority 6: Web UI (опционально)
    WebSocket integration        :p6a, after p3c, 3d
    Live price feeds             :p6b, after p6a, 2d
    Logging migration slog       :p6c, after p1c, 1d
    Advanced analytics           :p6d, after p6b, 2d
```

**Итого:**
- **Week 1-2**: Стандартизация + CTS-Core Phase 1 complete
- **Week 3-4**: WebSocket infrastructure (CTS-Core + Trader)
- **Week 5+**: Business logic, testing, production hardening
- **Week 6+** (опционально): Web UI enhancements (live updates, price feeds)

---

## 🎯 Success Criteria

### Week 1 (Стандартизация)
- [ ] Все сервисы: логи видны в `docker logs`
- [ ] Единый формат: JSON (slog)
- [ ] Единая конфигурация: YAML + ENV
- [ ] Все healthchecks работают
- [ ] Документация обновлена

### Week 2 (CTS-Core Phase 1 Complete)
- [ ] State management работает (load/save/recovery)
- [ ] REST API доступен (5 endpoints)
- [ ] Все тесты проходят (unit + integration)
- [ ] OpenAPI спецификация готова

### Week 3-4 (WebSocket Infrastructure)
- [ ] Trader может подключиться к CTS-Core через WS
- [ ] Регистрация + heartbeat работает
- [ ] Task assignment работает (1 trader)
- [ ] Load balancing работает (3 traders)

### Week 5+ (Production Ready)
- [ ] Все 3 Trader-а выполняют задачи
- [ ] Trade results processing работает
- [ ] Metrics в Prometheus
- [ ] Stress tests: 1000+ tasks/sec

---

## 📂 Структура документации

```
/home/dev/docker/ct-system/
├── DEVELOPMENT_PLAN.md          # ← Этот файл (общий план)
├── ARCHITECTURE.md              # Общая архитектура системы
├── LOGGING_ANALYSIS.md          # Анализ логирования (можно удалить после P1)
├── HSM_ROTATION.md              # HSM key rotation (готово)
├── README.md                    # Quick start
├── docker-compose.yml           # Оркестрация
│
└── services/
    ├── cts-core/
    │   ├── DEVELOPMENT_PLAN.md  # CTS-Core детальный план
    │   ├── ARCHITECTURE.md      # CTS-Core архитектура
    │   ├── API_SPECIFICATION.md # CTS-Core API
    │   └── guides/              # Phase-by-phase guides
    │
    ├── trader-daemon/
    │   ├── DEVELOPMENT_PLAN.md  # Trader детальный план
    │   └── ...
    │
    ├── hsm-service/
    │   ├── DEVELOPMENT_PLAN.md  # HSM improvements
    │   └── ...
    │
    └── web-ui-go/
        ├── internal/
        │   ├── controllers/
        │   │   ├── PHASE4_API.md      # Phase 4.1 Analytics API
        │   │   ├── USER_CONTROLLER.md
        │   │   └── GROUP_CONTROLLER.md
        │   └── logger/
        │       └── LOGGING.md         # Web UI logging (zerolog)
        └── config/
            └── config.yaml            # Web UI configuration
```

---

## 🔄 Workflow

### Daily Development

```bash
# 1. Проверить статус всех сервисов
make ps

# 2. Посмотреть логи (теперь работает для всех!)
docker logs ct-system-cts-core -f
docker logs ct-system-trader-1 -f

# 3. Запустить тесты
cd services/cts-core
make test

# 4. Пересобрать после изменений
make rebuild
make up
```

### Code Review Checklist

```
[ ] Logging: используется slog + JSON + stdout
[ ] Config: YAML с ENV override
[ ] Tests: unit + integration
[ ] Errors: wrapped с context
[ ] Healthcheck: работает
[ ] Docker logs: логи видны
[ ] Documentation: обновлена
```

---

## 📌 Важные заметки

1. **Не коммитить в git:**
   - `volumes/` (данные Docker)
   - `.env` (секреты)
   - `logs/` (логи)
   - `state/` (состояние демонов)

2. **Git структура:**
   - Корень: оркестрация (docker-compose, Makefile)
   - `services/*`: каждый имеет свой `.git/`

3. **HSM Key Rotation:**
   - Автопроверка: `./check-hsm-rotation-simple.sh`
   - Cron setup: см. `HSM_ROTATION.md`
   - 67 дней до следующей ротации ✅

4. **Приоритеты:**
   - 🔴 **P1**: Стандартизация (блокер для всего остального)
   - 🟡 **P2**: CTS-Core Phase 1 complete
   - 🟢 **P3-4**: WebSocket + Traders
   - ⚪ **P5**: HSM improvements (можно отложить)
   - ⚪ **P6**: Web UI enhancements (после WebSocket infrastructure)

---

## 🚀 Next Steps

**Сегодня (2026-02-01):**
1. ✅ Удалить MIGRATE_SYS_TO_DOCKER.md (выполнено)
2. ✅ Создать DEVELOPMENT_PLAN.md (этот файл)
3. 🔴 **Начать Priority 1.1**: Унификация логирования
   - Исправить CTS-Core logger (добавить stdout)
   - Исправить Trader logger (добавить stdout)
   - Протестировать `docker logs` для всех сервисов

**Завтра:**
- Продолжить Priority 1: конфигурация + healthchecks
- Начать Priority 2: Phase 1.4 State Management

**Вопросы для обсуждения:**
- Web UI: мигрировать на slog или оставить zerolog?
- Trader config: INI → YAML приоритет?
- CI/CD: какой pipeline предпочтительнее? (GitHub Actions, GitLab CI, Jenkins)

---

*Документ обновляется по мере прогресса. При возврате к проекту - начать с секции "Next Steps".*
