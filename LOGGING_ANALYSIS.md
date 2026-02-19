# Анализ логирования в системе CT-System

## Резюме

**Проблема:** В системе используются разные подходы к логированию, что приводит к несовместимости с Docker и усложняет мониторинг.

**Рекомендация:** Стандартизировать на подходе HSM Service - `log/slog` с выводом в `stdout` (JSON формат).

---

## Текущее состояние логирования

### ✅ HSM Service (эталон, v2.0.0)

**Файл:** `services/hsm-service/internal/server/logger.go`

**Библиотека:** `log/slog` (standard library Go 1.21+)

**Куда пишет:**
- ✅ **audit.log**: `/var/log/hsm-service/audit.log`
- ✅ **access.log**: `/var/log/hsm-service/access.log`
- ✅ **error.log**: `/var/log/hsm-service/error.log`
- ✅ **stdout**: audit/access могут дублироваться в stdout (видно в `docker logs`)

**Формат:** JSON (структурированный), UTC RFC3339 microseconds

**Ротация:** lumberjack (100MB, 10 backup, 30 дней, сжатие)

**Дополнительно:**
- request_id (X-Request-ID) в audit/access/error
- Fail-fast проверка доступности директории логов
- Graceful shutdown (SIGTERM/SIGINT) + `Shutdown(ctx)`
- Panic recovery с логированием stack trace в `error.log`

**Docker compatibility:** ✅ ОТЛИЧНО

---

### ⚠️ CTS-Core (почти готово)

**Файл:** `services/cts-core/internal/logger/logger.go`

**Библиотека:** `log/slog` (standard library)

**Вывод:**
```go
errorLogFile := &lumberjack.Logger{
    Filename:   filepath.Join(dir, "error.log"),
    MaxSize:    maxFileSizeMB,
    MaxBackups: 10,
    MaxAge:     30,
    Compress:   true,
}
writer := io.MultiWriter(os.Stdout, errorLogFile)
Log = slog.New(slog.NewJSONHandler(writer, &slog.HandlerOptions{Level: logLevel, ReplaceAttr: replaceTimeAttr}))
```

**Куда пишет:**
- ✅ **stdout + файл** `logs/error.log`
 - ✅ **логгеры для 6 файлов** (access/out_request/ws_access/ws_out/audit) сконфигурированы

**Целевая схема для CTS-Core (6 файлов):**
- error.log
- access.log
- out_request.log
- ws_access.log
- ws_out.log
- audit.log

**Формат:** JSON (UTC RFC3339 microseconds)

**Ротация:** lumberjack

**Проблемы:**
- ⚠️ WS обработчик пока stub (echo), нужен полноценный протокол

**Docker compatibility:** ✅ ХОРОШО

---

### ❌ Trader Daemon (нужна доработка + исправление прав)

**Файл:** `services/trader-daemon/internal/logger/logger.go`

**Библиотека:** `log/slog` (standard library)

**Вывод:**
```go
errorLogFile, err := os.OpenFile(filepath.Join(filepath.Clean(dir), "error.log"), 
    os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
errorRotated := &rotatedFile{
    file:     errorLogFile,
    filePath: filepath.Join(filepath.Clean(dir), "error.log"),
    maxSize:  maxLogSize,
}
Log = slog.New(&plainTextHandler{w: errorRotated, level: logLevel, module: "main"})

// Отдельный файл для торговли
tradeLogFile, err := os.OpenFile(filepath.Join(filepath.Clean(dir), "trade.log"), ...)
Trade = slog.New(&plainTextHandler{w: tradeRotated, level: logLevel, module: "trade"})
```

**Куда пишет:**
- ❌ **ТОЛЬКО в файлы** `logs/error.log` и `logs/trade.log`
- ❌ НЕ пишет в stdout

**Формат:** Plain text (legacy)

**Ротация:** Кастомная rotatedFile (legacy)

**Текущее состояние:**
```bash
$ docker logs ct-system-trader-1 --tail 5
Failed to init logger: open logs/error.log: permission denied
Failed to init logger: open logs/error.log: permission denied
Failed to init logger: open logs/error.log: permission denied
```
⚠️ **Критическая ошибка: нет прав на создание файлов логов**

**Проблемы:**
- ❌ `docker logs ct-system-trader-1` показывает ТОЛЬКО ошибки permission denied
- ❌ Контейнер работает от root, но volume logs смонтирован с UID 1001
- ❌ Нужно исправить права доступа в Dockerfile или docker-compose.yml
- ❌ Обычные логи не попадают в docker logs
- ❌ Два отдельных файла усложняют анализ
- ❌ Не стандартный для Docker подход

**Docker compatibility:** ❌ КРИТИЧНО (не работает вообще)

---

### ✅ Web UI (реализация унифицирована)

**Файл:** `services/web-ui-go/internal/logger/logger.go`

**Библиотека:** `log/slog` (standard library)

**Конфигурация:** (из `/app/config/config.yaml`)
```yaml
logging:
    level: "debug"
    format: "json"      # JSON (text допустим для debug)
    output: "both"      # ✅ stdout + file
    file: "/app/logs/error.log"
  max_size: 100
  max_backups: 5
  max_age: 30
  compress: true
```

**Ключевые особенности:**
- `error.log` + `access.log` + `audit.log` с раздельной ротацией
- `stdout + file` через MultiWriter
- fail-fast проверка записи в директорию логов
- graceful shutdown (`SIGTERM/SIGINT`, `server.Shutdown`, `logger.Close()`)
- модульные теги (`module`, авто + ручной override)
- Web-oriented audit middleware (auth + mutating actions)

**Куда пишет:**
- ✅ **stdout** (виден в `docker logs`)
- ✅ **file** `/app/logs/error.log`, `/app/logs/access.log`, `/app/logs/audit.log`

**Формат:** JSON (по умолчанию), text опционально

**Ротация:** lumberjack (100MB, 5 backup, 30 дней, сжатие)

**Пример вывода:**
```
2026-01-31T22:52:22Z INF cmd/web/main.go:311 > Loaded all HTML templates
2026-01-31T22:52:22Z INF cmd/web/main.go:333 > Starting HTTP server address=0.0.0.0:80 mode=debug
[GIN-debug] Listening and serving HTTP on 0.0.0.0:80
```

**Docker compatibility:** ✅ ОТЛИЧНО

---

## Сравнительная таблица

| Сервис | Библиотека | stdout | file | Формат | Docker logs | Статус |
|--------|-----------|--------|------|--------|-------------|--------|
| **HSM** | slog (stdlib) | ✅ | ✅ | JSON | ✅ Работает | ✅ Эталон |
| **Web UI** | slog (stdlib) | ✅ | ✅ | JSON | ✅ Работает | ✅ Готово |
| **CTS-Core** | slog (stdlib) | ✅ | ✅ | JSON | ✅ Работает | ⚠️ Почти готово |
| **Trader** | slog (stdlib) | ❌ | ❌ | Text | ❌ Permission denied | ❌ Критично |

---

## Критическая проблема: Trader Permission Denied

### Диагностика

```bash
$ docker logs ct-system-trader-1
Failed to init logger: open logs/error.log: permission denied
```

**Причина:** Volume `./services/trader-daemon/logs` принадлежит пользователю host (UID 1001), а контейнер запускается от root.

### Проверка прав

```bash
$ ls -la services/trader-daemon/
drwxrwxr-x  2 dev dev  4096 logs/

$ docker exec ct-system-trader-1 id
uid=0(root) gid=0(root) groups=0(root)

$ docker exec ct-system-trader-1 ls -la /app/logs
drwxrwxr-x 2 1001 1001 4096 logs/
```

Контейнер (root) не может писать в папку владельца 1001.

### Решение 1: Исправить права (быстрое)

```bash
# Дать права на запись всем
sudo chmod 777 services/trader-daemon/logs
```

### Решение 2: Запускать от пользователя (правильное)

**docker-compose.yml:**
```yaml
trader-1:
  # ...
  user: "1001:1001"  # Запускать от пользователя хоста
  volumes:
    - ./services/trader-daemon/logs:/app/logs
```

**Минус:** Может быть несовместимо с другими правами в контейнере.

### Решение 3: Создать папку в контейнере (рекомендуемое после миграции на stdout)

**docker-compose.yml:**
```yaml
trader-1:
  # ...
  # НЕ монтировать volume, создавать внутри контейнера
  # volumes:
  #   - ./services/trader-daemon/logs:/app/logs  # Удалить
```

**Плюсы:**
- Логи внутри контейнера, никаких проблем с правами
- После миграции на stdout файлы нужны только для архивации
- Можно собирать логи через `docker logs`

---

## Рекомендации по стандартизации

### 1. Общий подход (как в HSM)

**Стандарт:**
- Библиотека: `log/slog` (Go stdlib 1.21+)
- Формат: **JSON** (slog.NewJSONHandler)
- Вывод: **io.MultiWriter(os.Stdout, fileWriter)**
- Ротация файлов: **lumberjack.Logger**

**Преимущества:**
- ✅ Единая кодовая база для логирования
- ✅ Работает с `docker logs` (DevOps-friendly)
- ✅ JSON легко парсить (ELK, Grafana Loki, etc.)
- ✅ Файлы для долгосрочного хранения
- ✅ Нет внешних зависимостей (stdlib)

---

### 2. CTS-Core: остаточные задачи

**Статус:** JSON + stdout + lumberjack + request_id + access/out_request + ws/audit + graceful shutdown готовы (WS stub).

**Осталось:**
- Заменить WS stub на полноценный протокол.

---

### 3. Исправление Trader Daemon

**Файл:** `services/trader-daemon/internal/logger/logger.go`

**Аналогично CTS-Core:**

```go
func Init(levelStr, dir string, maxFileSizeMB int) error {
    if err := os.MkdirAll(dir, 0750); err != nil {
        return err
    }

    logDir = dir
    maxLogSize = int64(maxFileSizeMB) * 1024 * 1024

    // Parse level
    switch strings.ToLower(levelStr) {
    case "debug":
        logLevel = slog.LevelDebug
    case "info":
        logLevel = slog.LevelInfo
    case "warn":
        logLevel = slog.LevelWarn
    case "error":
        logLevel = slog.LevelError
    default:
        logLevel = slog.LevelInfo
    }

    // Main log (error + info)
    mainWriter := &lumberjack.Logger{
        Filename:   filepath.Join(dir, "trader.log"),
        MaxSize:    maxFileSizeMB,
        MaxBackups: 10,
        MaxAge:     30,
        Compress:   true,
    }
    mainMulti := io.MultiWriter(os.Stdout, mainWriter)

    Log = slog.New(slog.NewJSONHandler(mainMulti, &slog.HandlerOptions{
        Level: logLevel,
    }))

    // Trade log (отдельный файл + stdout)
    tradeWriter := &lumberjack.Logger{
        Filename:   filepath.Join(dir, "trade.log"),
        MaxSize:    maxFileSizeMB,
        MaxBackups: 10,
        MaxAge:     30,
        Compress:   true,
    }
    tradeMulti := io.MultiWriter(os.Stdout, tradeWriter)

    Trade = slog.New(slog.NewJSONHandler(tradeMulti, &slog.HandlerOptions{
        Level: logLevel,
    }))

    return nil
}
```

**Добавить зависимость:**
```bash
cd services/trader-daemon
go get gopkg.in/natefinch/lumberjack.v2
```

---

### 4. Проверка Web UI

**Проверить текущую конфигурацию:**

```bash
docker exec ct-system-web-ui cat /app/config/config.yaml | grep -A 20 "logging:"
```

Проверить, что включены оба потока (`error.log` + `access.log`):

`services/web-ui-go/config/config.yaml`:
```yaml
logging:
    output: "both"
    file: "/app/logs/error.log"
    access_file: "/app/logs/access.log"
```

**Статус:** миграция Web UI на `slog` уже выполнена

---

## План миграции

### Приоритет 1 (критично для Docker)

1. ❌ **Trader-1** - КРИТИЧНО: Исправить permission denied + добавить stdout
2. ⚠️ **CTS-Core** - Заменить WS stub на полноценный протокол
3. ✅ **Web UI** - Унификация выполнена (`slog` + split logs)

### Приоритет 2 (полировка)

4. Web UI: финальная валидация docker debug/release
5. Обновить эксплуатационную документацию по логированию
6. Настроить centralized logging (ELK/Loki)

---

## Пример использования после исправления

### До (текущее):

```bash
# Trader - ПУСТО/ошибка
docker logs ct-system-trader-1

# Нужно лезть в файл
docker exec ct-system-trader-1 tail -f /app/logs/error.log
```

### После (исправленное):

```bash
# Trader - РАБОТАЕТ
docker logs ct-system-trader-1
{"time":"2024-01-15T10:30:45Z","level":"INFO","msg":"Trader started","module":"main"}
{"time":"2024-01-15T10:30:46Z","level":"INFO","msg":"Connected to CTS-Core","module":"ws"}

# + файлы сохраняются для архивации
docker exec ct-system-trader-1 ls -lh /app/logs/
-rw-r--r-- 1 root root 45M Jan 15 10:30 trader.log
-rw-r--r-- 1 root root 12M Jan 10 14:22 trader.log.20240110_142203.gz
```

---

## Тестирование после исправлений

```bash
# 1. Пересобрать контейнеры
cd /home/dev/docker/ct-system
make build

# 2. Перезапустить
make down
make up

# 3. Проверить логи
docker logs ct-system-cts-core
docker logs ct-system-trader-1
docker logs ct-system-web-ui

# 4. Проверить файлы (должны дублироваться)
docker exec ct-system-cts-core ls -lh /app/logs/
docker exec ct-system-trader-1 ls -lh /app/logs/

# 5. Проверить JSON формат
docker logs ct-system-cts-core --tail 10 | jq '.'
```

---

## Выводы

1. **HSM Service** - эталон логирования ✅
   - slog + JSON + stdout + file
   - Работает идеально с Docker

2. **Web UI** - унифицирован ✅
    - slog + access/error split + stdout + file
    - Логи видны в docker logs
    - ✅ Финальная docker-валидация (debug/release) выполнена
    - ✅ Runbook добавлен: `services/web-ui-go/LOGGING_RUNBOOK.md`

3. **CTS-Core** - базовая унификация выполнена ✅
    - slog + JSON + stdout + lumberjack
    - Осталось: WS протокол (stub → production)

4. **Trader** - критическая проблема ❌
   - Permission denied при записи в logs/
   - Нужно исправить права или убрать volume
   - После этого добавить stdout как в HSM

5. **Преимущества стандартизации:**
   - Единый подход во всех сервисах
   - Совместимость с Docker
   - Легкость интеграции с системами мониторинга
   - Меньше кода (используем stdlib)

---

## Итоговая сводка по текущему состоянию

| Сервис | Docker Logs | Статус | Действия |
|--------|------------|--------|----------|
| **HSM** | ✅ Работают | ✅ Отлично | Нет, это эталон |
| **Web UI** | ✅ Работают | ✅ Отлично | Нет (hardening закрыт) |
| **CTS-Core** | ✅ Работают | ⚠️ Почти готово | WS протокол |
| **Trader-1** | ❌ Permission denied | ❌ Критично | 1) Исправить права<br>2) Добавить stdout |

**Общая оценка:** 3/4 сервисов работают корректно с Docker логированием.

**Приоритет действий:**
1. 🔴 Trader: Исправить permission denied (non-root user mapping + безопасные права bind-mount)
2. 🔴 Trader: Добавить stdout + JSON + lumberjack
3. 🟡 CTS-Core: WS protocol
4. 🟢 Web UI: поддерживать runbook и регрессионные проверки при изменениях
5. 🟢 Все: поддерживать единый slog/stdout/file стандарт

**Ожидаемый результат:** Все 4 сервиса выводят логи в `docker logs` в JSON формате.
