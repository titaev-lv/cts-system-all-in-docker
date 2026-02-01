# Анализ логирования в системе CT-System

## Резюме

**Проблема:** В системе используются разные подходы к логированию, что приводит к несовместимости с Docker и усложняет мониторинг.

**Рекомендация:** Стандартизировать на подходе HSM Service - `log/slog` с выводом в `stdout` (JSON формат).

---

## Текущее состояние логирования

### ✅ HSM Service (эталон, уже в production)

**Файл:** `services/hsm-service/main.go`

**Библиотека:** `log/slog` (standard library Go 1.21+)

**Вывод:**
```go
multiWriter := io.MultiWriter(os.Stdout, logWriter)
logger := slog.New(slog.NewJSONHandler(multiWriter, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))
```

**Куда пишет:**
- ✅ **stdout** (основной вывод, виден в `docker logs`)
- ✅ Дополнительно: `/var/log/hsm-service/hsm-service.log` (через lumberjack с ротацией)

**Формат:** JSON (структурированный)

**Ротация:** lumberjack (100MB, 10 backup, 30 дней, сжатие)

**Плюсы:**
- ✅ Работает с `docker logs`
- ✅ Структурированные JSON логи легко парсить
- ✅ Дублирование в файл для архивации
- ✅ Стандартная библиотека, без зависимостей

**Docker compatibility:** ✅ ОТЛИЧНО

---

### ❌ CTS-Core (нужна доработка)

**Файл:** `services/cts-core/internal/logger/logger.go`

**Библиотека:** `log/slog` (standard library)

**Вывод:**
```go
errorLogFile, err := os.OpenFile(errorLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
errorRotated := &rotatedFile{
    file:     errorLogFile,
    filePath: errorLogPath,
    maxSize:  maxLogSize,
}
Log = slog.New(&plainTextHandler{w: errorRotated, level: logLevel, module: "main"})
```

**Куда пишет:**
- ❌ **ТОЛЬКО в файл** `logs/error.log`
- ❌ НЕ пишет в stdout

**Формат:** Plain text (кастомный plainTextHandler)
```
2006-01-02 15:04:05.000000 [LEVEL] [module] message key=value
```

**Ротация:** Кастомная rotatedFile (переименование с timestamp)

**Текущее состояние:**
```bash
$ docker logs ct-system-cts-core --tail 5
fatal error: all goroutines are asleep - deadlock!

goroutine 1 [select (no cases)]:
main.main()
        /build/cmd/cts-core/main.go:179 +0xea5
```
⚠️ **Видны только фатальные ошибки из stderr, обычные логи НЕ видны**

**Проблемы:**
- ❌ `docker logs ct-system-cts-core` показывает ТОЛЬКО панику из stderr
- ❌ Обычные логи (info, warn, error) не видны в docker logs
- ❌ Нужно заходить в контейнер или использовать `make logs-core-file`
- ❌ Не стандартный для Docker подход
- ❌ Plain text формат сложнее парсить автоматически

**Docker compatibility:** ❌ ПЛОХО

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

**Формат:** Plain text (идентичен CTS-Core)

**Ротация:** Кастомная rotatedFile (идентична CTS-Core)

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

### ✅ Web UI (работает корректно)

**Файл:** `services/web-ui-go/internal/logger/logger.go`

**Библиотека:** `github.com/rs/zerolog` (внешняя зависимость)

**Конфигурация:** (из `/app/config/config.yaml`)
```yaml
logging:
  level: "debug"
  format: "text"      # Text формат (читаемый)
  output: "both"      # ✅ stdout + file
  file: "./logs/ct-system.log"
  max_size: 100
  max_backups: 5
  max_age: 30
  compress: true
```

**Вывод:**
```go
var writers []io.Writer

// stdout (работает)
if logCfg.Output == "stdout" || logCfg.Output == "both" {
    consoleWriter = zerolog.ConsoleWriter{
        Out:        os.Stdout,
        TimeFormat: time.RFC3339,
        NoColor:    false,
    }
    writers = append(writers, consoleWriter)
}

// file (работает)
if logCfg.Output == "file" || logCfg.Output == "both" {
    fileWriter := &lumberjack.Logger{
        Filename:   logCfg.File,
        MaxSize:    logCfg.MaxSize,
        MaxBackups: logCfg.MaxBackups,
        MaxAge:     logCfg.MaxAge,
        Compress:   logCfg.Compress,
        LocalTime:  true,
    }
    writers = append(writers, fileWriter)
}

multiWriter := io.MultiWriter(writers...)
globalLogger = zerolog.New(multiWriter).With().Timestamp().Logger()
```

**Куда пишет:**
- ✅ **stdout** (виден в `docker logs`)
- ✅ **file** `./logs/ct-system.log`

**Формат:** Text (zerolog.ConsoleWriter с цветами)

**Ротация:** lumberjack (100MB, 5 backup, 30 дней, сжатие)

**Пример вывода:**
```
2026-01-31T22:52:22Z INF cmd/web/main.go:311 > Loaded all HTML templates
2026-01-31T22:52:22Z INF cmd/web/main.go:333 > Starting HTTP server address=0.0.0.0:80 mode=debug
[GIN-debug] Listening and serving HTTP on 0.0.0.0:80
```

**Плюсы:**
- ✅ Работает с `docker logs`
- ✅ Читаемый формат для разработки
- ✅ Дублирование в файл

**Минусы:**
- ⚠️ Отличается от остальных (zerolog vs slog)
- ⚠️ Text формат сложнее парсить автоматически (лучше JSON)
- ⚠️ Дополнительная зависимость (не stdlib)

**Docker compatibility:** ✅ ХОРОШО (но лучше унифицировать на JSON)

---

## Сравнительная таблица

| Сервис | Библиотека | stdout | file | Формат | Docker logs | Статус |
|--------|-----------|--------|------|--------|-------------|--------|
| **HSM** | slog (stdlib) | ✅ | ✅ | JSON | ✅ Работает | ✅ Эталон |
| **Web UI** | zerolog | ✅ | ✅ | Text | ✅ Работает | ⚠️ Унифицировать |
| **CTS-Core** | slog (stdlib) | ❌ | ✅ | Text | ❌ Только panic | ❌ Исправить |
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
sudo chmod 777 services/cts-core/logs
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

### 2. Исправление CTS-Core

**Файл:** `services/cts-core/internal/logger/logger.go`

**Что изменить:**

```go
func Init(levelStr, dir string, maxFileSizeMB int) error {
    // Create log directory
    if err := os.MkdirAll(dir, 0755); err != nil {
        return err
    }

    logDir = dir
    maxLogSize = int64(maxFileSizeMB) * 1024 * 1024

    // Parse log level
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

    // Setup file writer with rotation
    fileWriter := &lumberjack.Logger{
        Filename:   filepath.Join(dir, "cts-core.log"),
        MaxSize:    maxFileSizeMB,
        MaxBackups: 10,
        MaxAge:     30,
        Compress:   true,
    }

    // ✅ ИСПРАВЛЕНИЕ: Добавить stdout
    multiWriter := io.MultiWriter(os.Stdout, fileWriter)

    // ✅ ИСПРАВЛЕНИЕ: Использовать JSON формат
    Log = slog.New(slog.NewJSONHandler(multiWriter, &slog.HandlerOptions{
        Level: logLevel,
    }))

    return nil
}
```

**Удалить:**
- ❌ `rotatedFile` struct (заменить на lumberjack)
- ❌ `plainTextHandler` struct (использовать JSON)

**Добавить зависимость:**
```bash
cd services/cts-core
go get gopkg.in/natefinch/lumberjack.v2
```

---

### 3. Исправление Trader Daemon

**Файл:** `services/trader-daemon/internal/logger/logger.go`

**Аналогично CTS-Core:**

```go
func Init(levelStr, dir string, maxFileSizeMB int) error {
    if err := os.MkdirAll(dir, 0755); err != nil {
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
docker exec ct-system-web-ui cat /app/conf/config.yaml | grep -A 15 "logging:"
```

**Если output = "file":**

Изменить в `services/web-ui-go/conf/config.yaml`:
```yaml
logging:
  level: info
  format: json         # JSON для структурированных логов
  output: both         # stdout + file для Docker
  file: logs/web-ui.log
  max_size: 100
  max_backups: 10
  max_age: 30
  compress: true
```

**Опционально:** Мигрировать на slog (как все остальные)

---

## План миграции

### Приоритет 1 (критично для Docker)

1. ❌ **Trader-1** - КРИТИЧНО: Исправить permission denied + добавить stdout
2. ❌ **CTS-Core** - Добавить stdout в logger.go
3. ✅ **Web UI** - Уже работает, но можно унифицировать на JSON

### Приоритет 2 (унификация)

4. Мигрировать Web UI с zerolog на slog (опционально)
5. Обновить документацию по логированию
6. Настроить centralized logging (ELK/Loki)

---

## Пример использования после исправления

### До (текущее):

```bash
# CTS-Core - ПУСТО
docker logs ct-system-cts-core

# Нужно лезть в файл
docker exec ct-system-cts-core tail -f /app/logs/error.log
```

### После (исправленное):

```bash
# CTS-Core - РАБОТАЕТ
docker logs ct-system-cts-core
{"time":"2024-01-15T10:30:45Z","level":"INFO","msg":"Server started","port":"8080"}
{"time":"2024-01-15T10:30:46Z","level":"INFO","msg":"Connected to HSM","hsm":"hsm-service:8443"}

# + файлы сохраняются для архивации
docker exec ct-system-cts-core ls -lh /app/logs/
-rw-r--r-- 1 root root 45M Jan 15 10:30 cts-core.log
-rw-r--r-- 1 root root 12M Jan 10 14:22 cts-core.log.20240110_142203.gz
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

2. **Web UI** - работает хорошо ✅
   - zerolog + text + stdout + file
   - Логи видны в docker logs
   - Можно унифицировать на slog + JSON

3. **CTS-Core** - нужны исправления ❌
   - Используют slog, но только в файл
   - Видны только фатальные ошибки (stderr)
   - Простое исправление: добавить io.MultiWriter

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
| **Web UI** | ✅ Работают | ✅ Хорошо | Опционально: JSON вместо text |
| **CTS-Core** | ⚠️ Только panic | ❌ Плохо | Добавить stdout в logger.go |
| **Trader-1** | ❌ Permission denied | ❌ Критично | 1) Исправить права<br>2) Добавить stdout |

**Общая оценка:** 2/4 сервисов работают корректно с Docker логированием.

**Приоритет действий:**
1. 🔴 Trader: Исправить permission denied (chmod 777 logs/)
2. 🔴 Trader: Добавить stdout в logger.go
3. 🟡 CTS-Core: Добавить stdout в logger.go
4. 🟢 Web UI: Опционально сменить text на json
5. 🟢 Все: Унифицировать на slog stdlib

**Ожидаемый результат:** Все 4 сервиса выводят логи в `docker logs` в JSON формате.
