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
| Web UI migration to slog + split logs | Web UI | Medium | 2-3d | ✅ Done |
| Web UI validation + runbook | Web UI | Easy | 1d | ✅ Done |
| HSM reference (audit/access/error, request_id, fail-fast, graceful shutdown, panic recovery) | HSM | Done | - | ✅ |

---

## 🔧 CTS-Core: Logging Fix (ALMOST DONE)

CTS-Core переведен на JSON + stdout + lumberjack, логгеры/файлы разделены, request_id + access/out_request + ws/audit + graceful shutdown подключены (WS stub).

**Осталось сделать:**
- Заменить WS stub на полноценный протокол

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

## 🔧 Web UI: Logging Status & Final Hardening (1 day)

### Current status (implemented)
- ✅ `slog` logger in `services/web-ui-go/internal/logger/logger.go`
- ✅ Split streams: `error.log` + `access.log`
- ✅ Access middleware wired in `cmd/web/main.go`
- ✅ `request_id` middleware + `X-Request-ID` propagation (context/response/access/error)
- ✅ Fail-fast on log directory write access
- ✅ Graceful shutdown with `logger.Close()`

### Final checklist (what to finish)
- [x] Validate `docker logs ct-system-web-ui-1` in debug and release modes
- [x] Validate that both `access.log` and `error.log` are present in `/app/logs`
- [x] Verify rotation files appear under load (`access.log.*`, `error.log.*`)
- [x] Confirm key fields: `request_id`, `module`, `method`, `path`, `status`, `latency_ms`, `user_id`
- [x] Finalize short runbook for operational troubleshooting

Runbook: `services/web-ui-go/LOGGING_RUNBOOK.md`

### Verify

```bash
docker-compose up web-ui-1
docker logs ct-system-web-ui-1 | jq . | head -20

# Should show JSON logs with "method", "status", "duration_ms" fields
# Check both logs exist:
ls -lh /app/logs/
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

# If running in containerized setup used by Web UI:
ls /app/logs/
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
