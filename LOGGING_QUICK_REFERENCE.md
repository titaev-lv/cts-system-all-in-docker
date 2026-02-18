# Quick Reference: Logging Unification Implementation

> **Created:** 2026-02-18  
> **Focus:** CTS-Core, Trader, Web UI recovery  
> **Updated by:** 2026 development team

---

## 📋 At a Glance

| Task | Service | Complexity | Time | Status |
|------|---------|-----------|------|--------|
| Add stdout + JSON | CTS-Core | Easy | 0.5d | ✅ Done |
| Add stdout + JSON | Trader | Easy | 0.5d | Priority |
| Migrate legacy logger → slog | Web UI | Medium | 2-3d | Priority |
| Add access logging | Web UI | Medium | 1d | With migration |
| HSM reference (audit/access/error, request_id, fail-fast, graceful shutdown, panic recovery) | HSM | Done | - | ✅ |

---

## 🔧 CTS-Core: Logging Fix (DONE)

CTS-Core уже переведен на JSON + stdout + lumberjack.

**Осталось сделать:**
- Добавить request_id middleware
- Разделить логи на error/access/out_request/ws_access/ws_out/audit

### Verify

```bash
docker-compose up cts-core-1
docker logs ct-system-cts-core-1 | head
# Should show JSON strings like: {"time":"2026-02-10...","level":"INFO","msg":"Connected"...}
```

---

## 🔧 Trader Daemon: Logging Fix (30 minutes)

**Identical to CTS-Core:**

1. Add `os.Stdout` to MultiWriter
2. Switch to `slog.NewJSONHandler`
3. Replace `rotatedFile` with `lumberjack`

**File:** `services/trader-daemon/internal/logger/logger.go`

**Note:** Trader already has Trade logger module - it will automatically include `"module":"trade"` in JSON output.

---

## 🔧 Web UI: Logging Migration (2-3 days)

### Phase 1: Remove legacy logger dependency (1 day)

**Step 1: Remove from go.mod**
```bash
cd services/web-ui-go
go mod edit -droprequire <legacy-logger-module>
rm go.sum
go mod tidy
```

**Step 2: Find & replace imports**
```bash
# Find all occurrences:
grep -r "legacy logger" .

# Replace with:
grep -r "log/slog" .
```

**Step 3: Update logger.go**

Replace entire file with slog-based implementation:

```go
package logger

import (
    "io"
    "log/slog"
    "os"
    "path/filepath"
    "github.com/natefinch/lumberjack"
)

var (
    errorLog *slog.Logger
    accessLog *slog.Logger
)

func Init(dir string, maxFileSizeMB int) error {
    // Error log
    errorLogFile := &lumberjack.Logger{
        Filename:   filepath.Join(dir, "error.log"),
        MaxSize:    maxFileSizeMB,
        MaxBackups: 5,
        MaxAge:     30,
        Compress:   true,
    }
    errorWriter := io.MultiWriter(os.Stdout, errorLogFile)
    errorLogHandler := slog.NewJSONHandler(errorWriter, &slog.HandlerOptions{Level: slog.LevelInfo})
    errorLog = slog.New(errorLogHandler)
    slog.SetDefault(errorLog)
    
    // Access log
    accessLogFile := &lumberjack.Logger{
        Filename:   filepath.Join(dir, "access.log"),
        MaxSize:    50,  // smaller for access logs
        MaxBackups: 10,
        MaxAge:     7,
        Compress:   true,
    }
    accessWriter := io.MultiWriter(os.Stdout, accessLogFile)
    accessLogHandler := slog.NewJSONHandler(accessWriter, &slog.HandlerOptions{Level: slog.LevelInfo})
    accessLog = slog.New(accessLogHandler)
    
    return os.MkdirAll(dir, 0755)
}

func GetError() *slog.Logger {
    return errorLog
}

func GetAccess() *slog.Logger {
    return accessLog
}
```

### Phase 2: Add access logging middleware (1 day)

**File:** `services/web-ui-go/internal/middleware/access_log.go` (NEW)

```go
package middleware

import (
    "time"
    "github.com/gin-gonic/gin"
    "yourmodule/internal/logger"
)

func AccessLogMiddleware() gin.HandlerFunc {
    accessLog := logger.GetAccess()
    
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        duration := time.Since(start)
        
        // Extract user_id from session
        userID := extractUserID(c)  // implement based on your auth
        
        accessLog.Info("HTTP request",
            slog.String("method", c.Request.Method),
            slog.String("path", c.Request.URL.Path),
            slog.Int("status", c.Writer.Status()),
            slog.Int64("duration_ms", duration.Milliseconds()),
            slog.String("client_ip", c.ClientIP()),
            slog.Any("user_id", userID),
        )
    }
}

func extractUserID(c *gin.Context) *uint {
    // Extract from session/context
    // Return nil if not authenticated
    return nil
}
```

**Add to main router setup:**

```go
// cmd/web/main.go
r := gin.New()
r.Use(middleware.AccessLogMiddleware())  // Add this early
// ... other middleware
```

### Phase 3: Update config (0.5 day)

**File:** `services/web-ui-go/conf/config.yaml`

```yaml
app:
  name: "CT-System Web UI"
  port: 8080

logging:
  level: "info"
  dir: "/var/log/web-ui"
  max_file_size_mb: 100
  access_log:
    enabled: true
    max_file_size_mb: 50
    
# rest of config...
```

### Verify

```bash
docker-compose up web-ui-1
docker logs ct-system-web-ui-1 | jq . | head -20

# Should show JSON logs with "method", "status", "duration_ms" fields
# Check both logs exist:
ls -lh /var/log/web-ui/
  access.log
  error.log
```

---

## ✅ Validation Checklist

### All Services

- [ ] `docker logs <service>` shows logs (not empty)
- [ ] Logs are JSON format (valid JSON)
- [ ] Files exist in /var/log/{service}/
- [ ] Log rotation works (after some time/size)

### CTS-Core & Trader

```bash
docker logs ct-system-cts-core-1 | jq .
# Expected: {"time":"...","level":"INFO","msg":"...","module":"..."}
```

### Web UI

```bash
docker logs ct-system-web-ui-1 | jq .
# Should contain both patterns:
# 1. {"time":"...","method":"GET","path":"/api/...","status":200,...}  # access
# 2. {"time":"...","level":"ERROR","msg":"...","module":"api",...}     # error

ls /var/log/web-ui/
# access.log and error.log should both exist
```

---

## 📚 Reference Documents

- [LOGGING_ANALYSIS_DETAILED.md](../LOGGING_ANALYSIS_DETAILED.md) — Full analysis of current state
- [services/hsm-service/internal/server/logger.go](../services/hsm-service/internal/server/logger.go) — Reference implementation
- [services/cts-core/DEVELOPMENT_PLAN.md](../services/cts-core/DEVELOPMENT_PLAN.md#3-unifikacija-logirovanija) — Detailed plan
- [services/web-ui-go/DEVELOPMENT_PLAN.md](../services/web-ui-go/DEVELOPMENT_PLAN.md#-kritichno-unifikacija-logirovanija) — Web UI specifics

---

## 🚀 Quick Commands

```bash
# Test all logs are visible
make test-logs

# Check log files exist
ls -lh /var/log/*/

# Watch logs in real-time
docker-compose logs -f

# Validate JSON format
docker logs ct-system-cts-core-1 | head -5 | jq .
docker logs ct-system-web-ui-1 | head -5 | jq .

# Check rotation works (after creating large logs)
find /var/log -name "*.gz" -o -name "*.1"
```
