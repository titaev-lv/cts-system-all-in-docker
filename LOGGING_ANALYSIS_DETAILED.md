# Детальный анализ логирования (2026-02-18)

## 📊 Сравнительная таблица

| Параметр | HSM Service | CTS-Core | Trader | Web UI (Go) |
|----------|------------|----------|--------|------------|
| **Библиотека** | `slog` ✅ | `slog` ✅ | `slog` ✅ | external logger ❌ |
| **Формат** | JSON | JSON | Text (plain) | JSON/Text |
| **Ротация** | `lumberjack` ✅ | `lumberjack` ✅ | Кастомный | `lumberjack` ✅ |
| **MultiWriter** | Да (stdout+file) | Да (stdout+file) | Да (file) | Да (stdout+file) |
| **Модульность** | ✅ module tags | ✅ module tag (Get("module")) | ✅ module tag (Get("module")) | Нет ❌ |
| **Access Log** | access.log | access.log + ws_access.log (target) | - | ❌ Не разделены |
| **Error Log** | error.log + audit.log | error.log + audit.log (target) | - | ❌ Не разделены |
| **Проверка прав** | ✅ Fail-fast | ✅ Fail-fast | ✅ MkdirAll | ✅ MkdirAll |
| **Graceful shutdown** | ✅ SIGTERM/SIGINT + Shutdown(ctx) + Close | ⚠️ Только Close | ⚠️ Только Close | ❌ Нет |
| **Защита от паник** | ✅ Recovery middleware | ❌ Нет | Кастомный plain handler | legacy logger default |

---

## 🔍 Детальный анализ по проектам

### 1. HSM Service ✅ (Эталончик, v2.0.0)

**Плюсы:**
- ✅ slog + JSON формат (UTC RFC3339 microseconds)
- ✅ lumberjack ротация (100MB, keep 10, 30 days)
- ✅ Разделение audit.log, access.log и error.log
- ✅ request_id и аудит-метаданные (status/result/error_code, key_id)
- ✅ Fail-fast проверка доступности директории логов
- ✅ module tags (api/acl/crypto/middleware/rate_limit)

**Initialization (упрощенно):**
```go
// internal/server/logger.go
errorWriter := io.MultiWriter(os.Stdout, errorLogFile)
auditWriter := io.MultiWriter(os.Stdout, auditLogFile)
accessWriter := io.MultiWriter(os.Stdout, accessLogFile)
errorLogger := slog.New(slog.NewJSONHandler(errorWriter, opts))
auditLogger := slog.New(slog.NewJSONHandler(auditWriter, opts))
accessLogger := slog.New(slog.NewJSONHandler(accessWriter, opts))
```

**Реализовано: graceful shutdown + panic recovery (HSM)**
- Обработка `SIGTERM/SIGINT` с `server.Shutdown(ctx)`.
- Закрытие лог‑writers через `CloseLogger()` при остановке.
- Recovery middleware: логирование panic в `error.log` со stack trace и `request_id`, ответ 500.
- Unit‑тест на recovery middleware.

---

### 2. CTS-Core ⚠️ (Старт приведения к стандарту)

**Плюсы:**
- ✅ slog + JSON формат
- ✅ stdout + file (видно в docker logs)
- ✅ lumberjack ротация
- ✅ Fail-fast проверка доступности директории логов (write/rename)
- ✅ Модульное логирование: Get("main"), Get("database"), Get("hsm")
- ✅ Graceful shutdown (частично): `defer logger.Close()`

**Минусы:**
- ❌ Нет разделения error/access/out_request/ws_access/ws_out/audit
- ❌ Нет request_id и middleware для его прокидывания
- ❌ Нет обработки SIGTERM/SIGINT и Shutdown(ctx) как в HSM (нужно унифицировать)

**Initialization код (обновлено):**
```go
// cmd/cts-core/main.go
cfg, err := config.Load(*configPath)
// ... handle err
if err := logger.Init(
    cfg.Logging.Level,
    cfg.Logging.Dir,
    cfg.Logging.MaxFileSizeMB,
    cfg.Logging.MaxBackups,
    cfg.Logging.MaxAgeDays,
    cfg.Logging.Compress,
); err != nil {
    fmt.Fprintf(os.Stderr, "Failed to initialize logger: %v\n", err)
    os.Exit(1)
}
defer logger.Close()
log := logger.Get("main")
```

**Модульное логирование:**
```go
// lines 46-47
dbLogger := logger.Get("database")
hsmLogger := logger.Get("hsm")
```

---

### 3. Trader (ctdaemon) ⚠️ (Аналогично CTS-Core)

**Плюсы:**
- ✅ slog
- ✅ Модульное логирование: Get("main"), Get("trade"), Get("monitor"), Get("orderbook")
- ✅ MkdirAll() проверка
- ✅ Graceful shutdown: `defer logger.Close()`
- ✅ Специализированный Trade логгер для торговых операций

**Минусы:**
- ❌ Кастомный rotatedFile вместо lumberjack (нет gzip, нет очистки по датам)
- ❌ Plain text формат (не JSON)
- ❌ Только file, БЕЗ stdout (docker logs пусто!)
- ❌ Интент: может писать Trade логи в отдельный файл, но реализация не завершена

**Initialization код:**
```go
// cmd/daemon/main.go lines 47-52
if err := logger.Init(cfg.Log.Level, cfg.Log.Dir, cfg.Log.MaxFileSizeMB); err != nil {
    fmt.Printf("Failed to init logger: %+v\n", err)
    os.Exit(1)
}
defer logger.Close()
log := logger.Get("main")
```

**Специализированные логгеры:**
```go
// Планируется использовать Trade логгер отдельно
Trade := logger.Get("trade")
```

---

### 4. Web UI (Go) ❌ (Нужна коренная переделка)

**Плюсы:**
- ✅ legacy logger (похожа на slog, но внешняя зависимость)
- ✅ lumberjack ротация
- ✅ stdout + file

**Минусы:**
- ❌ legacy logger вместо `slog` (не стандартная библиотека, зависимость)
- ❌ Нет модульного логирования (компоненты не различимы в логах)
- ❌ Модульность HTTP запросов требует разделения на access/error logы
- ❌ Нет graceful shutdown логирования
- ❌ Нет проверки доступа на запись директории перед использованием
- ❌ Жестко в FormData() просит все параметры - нет возможности пропустить нужно обновить на SetEnvKeyReplacer

**Initialization код:**
```go
// cmd/web/main.go lines 40-45
logger.Init() // Без параметров
log := logger.Get() // Глобальный логгер, нет модульности
```

---

## 🎯 Требования унификации

### 1. **Использовать одну библиотеку везде**
- ✅ Стандарт: `log/slog` (встроенная в go 1.21+)
- 🚫 Не использовать: внешние логгеры (logrus и т.д.)

### 2. **Одинаковый механизм ротации**
- ✅ Везде: `lumberjack.Logger` (https://github.com/natefinch/lumberjack)
- 🚫 Не использовать: кастомный rotatedFile

**Параметры ротации (унифицированные):**
```go
&lumberjack.Logger{
    // Для логов приложения (error.log)
    Filename:   "/app/logs/error.log",  // или /var/log/app/error.log
    MaxSize:    100,    // MB
    MaxBackups: 5,      // старых файлов
    MaxAge:     30,     // дней
    Compress:   true,   // gzip архивирование
}

// Для access.log (web-ui-go только)
&lumberjack.Logger{
    Filename:   "/app/logs/access.log",
    MaxSize:    50,     // access логи растут быстрее
    MaxBackups: 10,
    MaxAge:     7,      // access логи хранить 7 дней
    Compress:   true,
}
```

### 3. **Формат везде JSON**
- ✅ JSON Handler: `slog.NewJSONHandler(writer, opts)`
- 🚫 Text формат только для development mode

### 4. **Обязательна проверка доступа на запись логов**
```go
// До создания логгера
logDir := cfg.Logging.Dir
if err := os.MkdirAll(logDir, 0750); err != nil {
    fmt.Fprintf(os.Stderr, "FATAL: Cannot create log directory %s: %v\n", logDir, err)
    os.Exit(1)
}

// ДОПОЛНИТЕЛЬНО: проверить что можно писать
testFile := filepath.Join(logDir, ".write-test")
if err := os.WriteFile(testFile, []byte("test"), 0600); err != nil {
    fmt.Fprintf(os.Stderr, "FATAL: Cannot write to log directory %s: %v\n", logDir, err)
    os.Exit(1)
}
os.Remove(testFile)
```

### 5. **Модульное логирование везде**
```go
// Инициализация
logger := slog.With("module", "main")
dbLogger := slog.With("module", "database")
hsmLogger := slog.With("module", "hsm")

// Результат в логе:
// {"timestamp":"...","level":"info","message":"Connected","module":"database"}
```

**Стандарт:** модульность задается атрибутом `module`. Реализация через `Get("module")` эквивалентна `slog.With("module", ...)`.

### 6. **Graceful shutdown везде**
```go
// В main.go
if err := logger.Init(cfg); err != nil {
    // panic или fatal
}
defer logger.Close() // Закрыть файлы логов перед выходом
```

**Стандарт:** обязательно обрабатывать `SIGTERM/SIGINT`, вызывать `server.Shutdown(ctx)` и закрывать логгеры.

### 7. **Stdout + File везде**
- Все логи одновременно в файл И в stdout
- Позволяет:
  - Видеть логи в `docker logs <container>`
  - Собирать логи в файл для анализа
  - Интегрировать с ELK/Loki/Grafana

### 8. **Web UI: разделение на access/error**
```
logs/
├── access.log*     # HTTP запросы - метод, путь, статус, время, IP
├── access.log.1    # Ротированные
├── error.log*      # Ошибки приложения, события, паники
└── error.log.1
```

---

## 📋 Чек-лист реализации

### HSM Service
- [x] slog + JSON
- [x] lumberjack ротация
- [x] stdout + file
- [x] module tags (api/acl/crypto/middleware/rate_limit)
- [x] Fail-fast проверка доступа на запись
- [x] Разделение audit.log, access.log и error.log
- [x] request_id и audit metadata
- [x] Graceful shutdown (SIGTERM/SIGINT + Shutdown(ctx) + CloseLogger)
- [x] Panic recovery (error.log + stack)

### CTS-Core
- [x] slog
- [x] Модульное логирование
- [x] MkdirAll проверка
- [ ] **НУЖНО СДЕЛАТЬ**: Заменить кастомный rotatedFile на lumberjack
- [ ] **НУЖНО СДЕЛАТЬ**: Изменить формат с text на JSON
- [ ] **НУЖНО СДЕЛАТЬ**: Добавить stdout + file (сейчас только file)

### Trader
- [x] slog
- [x] Модульное логирование  
- [x] MkdirAll проверка
- [ ] **НУЖНО СДЕЛАТЬ**: Заменить кастомный rotatedFile на lumberjack
- [ ] **НУЖНО СДЕЛАТЬ**: Изменить формат с text на JSON
- [ ] **НУЖНО СДЕЛАТЬ**: Добавить stdout + file (сейчас только file)
- [ ] **НУЖНО СДЕЛАТЬ**: Завершить реализацию Trade модуля логирования

### Web UI (Go)
- [ ] **НУЖНО СДЕЛАТЬ**: Заменить legacy logger на slog
- [ ] **НУЖНО СДЕЛАТЬ**: Удалить зависимость legacy logger
- [ ] **НУЖНО СДЕЛАТЬ**: Добавить модульное логирование
- [ ] **НУЖНО СДЕЛАТЬ**: Разделить логи на access.log + error.log
- [ ] **НУЖНО СДЕЛАТЬ**: Добавить graceful shutdown (defer logger.Close())
- [ ] **НУЖНО СДЕЛАТЬ**: Добавить проверку доступа на запись
- [ ] **НУЖНО СДЕЛАТЬ**: Добавить request logging middleware для access.log

---

## 🔧 Порядок миграции

### Phase 1: Web UI (критичный для стандартизации)
1. Заменить legacy logger → slog
2. Добавить разделение access/error логов
3. Модульное логирование (module в каждом компоненте)

### Phase 2: CTS-Core + Trader
1. Заменить rotatedFile → lumberjack
2. Изменить text → JSON
3. Добавить stdout + file
4. Добавить проверку прав на запись

### Phase 3: HSM Service
1. ✅ Выполнено: audit/access/error, request_id, fail-fast, graceful shutdown, panic recovery

### Phase 4: Валидация
1. Все проекты логируют в JSON формате
2. Все логи видны в docker logs
3. Все логи ротируются через lumberjack
4. Нет возможности запуска без доступа на запись логов
