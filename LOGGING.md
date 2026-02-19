# Logging Unification: Single Source of Truth

> Consolidated from previous `LOGGING_*` root documents into one detailed file.
> Last update: 2026-02-20

---

## 1) Executive Summary

### Current status

| Service | Library | Format | Streams | Stdout | Rotation | request_id | Status |
|---|---|---|---|---|---|---|---|
| HSM | `log/slog` | JSON | `error` + `access` + `audit` | ✅ | ✅ `lumberjack` | ✅ | ✅ Reference |
| CTS-Core | `log/slog` | JSON | `error` + `access` + `out_request` + `ws_*` + `audit` | ✅ | ✅ `lumberjack` | ✅ | ⚠️ WS protocol hardening |
| Trader | `log/slog` | Mixed/legacy in flow | partially split | ⚠️ | ⚠️ | ⚠️ | ❗ Priority migration |
| Web-UI Go | `log/slog` | JSON/Text | `error` + `access` + `audit` | ✅ | ✅ `lumberjack` | ✅ | ✅ Implemented + hardened |

### What is already closed for Web-UI
- `request_id` middleware + header propagation (`X-Request-ID`)
- `access/error` split + fail-fast + graceful shutdown
- Web-UI oriented `audit.log` + audit middleware
- Debug/release regression checks
- Operational runbook

Runbook: `services/web-ui-go/LOGGING_RUNBOOK.md`

---

## 2) Unified Logging Standard

### Mandatory baseline
- Logging library: `log/slog`
- Format: JSON (text allowed only for explicit local debug use-cases)
- Output mode: `stdout + file` (`output: both`)
- Rotation: `lumberjack` (size/backups/age/compress)
- Correlation: `request_id` for request-bound events
- Startup safety: fail-fast on non-writable log directory

### Request correlation policy
- Request-bound events: `request_id` REQUIRED
- System/background events: `request_id` OPTIONAL
- For non-request events use stable IDs (`job_id`, `task_id`, `event_id`)

### Web service stream model
- `error.log`: app errors/recovery/system faults
- `access.log`: HTTP access events
- `audit.log`: security/admin mutating actions (or compliance events where relevant)

---

## 3) Service-by-Service Detailed Analysis

## HSM (reference)

### Why `audit.log` is mandatory here
HSM handles cryptographic operations and security boundaries. Audit trail is compliance-critical:
- operation context
- key-related metadata
- client certificate identity
- result/error code
- request correlation

### Practical shape
- Streams: `error.log`, `access.log`, `audit.log`
- Audit middleware logs every relevant request with security context
- Audit can mirror to stdout (for container observability)

---

## CTS-Core

### Why `audit.log` is needed
CTS-Core orchestrates critical control-plane operations (traders, config, assignments, key lifecycle interactions). These are not just access events; they are auditable state changes.

### Current implementation highlights
- Dedicated audit logger stream exists
- REST mutating calls are audited
- Audit model/repository exists for retention/query flow

### Remaining scope
- WS protocol hardening / completion around event flow consistency

---

## Trader

### Current risk profile
- Logging not fully aligned to unified standard
- Operational pain persists in container observability path

### Priority work
- Ensure stable `stdout + file`
- Normalize JSON format path
- Complete split and safe rotation patterns

---

## Web-UI Go

### Why `audit.log` is useful (Web-UI oriented)
Web-UI executes admin/control actions (auth + CRUD/mutating endpoints). Access log alone is insufficient for incident response because it lacks action semantics and actor context.

### Implemented in Web-UI
- `error.log` + `access.log` + `audit.log`
- `AuditLogMiddleware` for Web-UI security/admin events
- `request_id` propagation into access/error/audit
- `X-Request-ID` response echo
- graceful shutdown + logger close
- fail-fast writable check

### Audit event shape (Web-UI)
- `event_type`
- `action`
- `resource_type`
- `method`, `path`, `status`, `result`
- `request_id`
- `user_id`, `user_login` (when available)
- `ip`, `user_agent`, `latency_ms`

### Web-UI validation status
- Debug profile: verified
- Release profile: verified
- `audit.log` file created: verified
- `audit` events in `docker logs`: verified

---

## 4) Verification Checklist (Detailed)

### A. Core health
- [ ] Service starts without logger init fallback
- [ ] No permission-denied on log paths
- [ ] `docker logs <service>` non-empty

### B. Format and fields
- [ ] JSON parseable output
- [ ] Required core fields exist (`time`, `level`, `msg`)
- [ ] `module` field present
- [ ] `request_id` present for request-bound events

### C. Stream split
- [ ] `error.log` exists
- [ ] `access.log` exists
- [ ] `audit.log` exists (where applicable)

### D. Rotation
- [ ] Rotated files appear under load
- [ ] Compression artifacts (`.gz`) appear as configured

### E. Security and audit semantics
- [ ] Mutating/admin actions are audited
- [ ] Audit carries actor/correlation metadata
- [ ] Non-request events use stable correlation IDs when request_id absent

---

## 5) Operational Commands

### Web-UI quick checks
```bash
docker compose up -d web-ui
docker logs --since 2m ct-system-web-ui | tail -n 50

curl -sSI -H 'X-Request-ID: check-001' -X POST http://127.0.0.1/auth/login | grep -i '^X-Request-Id:'

docker logs --since 2m ct-system-web-ui 2>&1 | grep -E '"event_type":"audit"|check-001|"module":"audit"' | tail -n 20
ls -lh services/web-ui-go/logs/
```

### CTS-Core quick checks
```bash
docker compose up -d cts-core
docker logs --since 2m ct-system-cts-core | tail -n 80
```

---

## 6) Priority Queue (Now)

1. Trader: finish migration to unified JSON + stdout + rotation path
2. CTS-Core: WS protocol hardening completion
3. Keep Web-UI audit/access/error schema stable and compatible with future centralized ingestion

---

## 7) Canonical References

- `DEVELOPMENT_PLAN.md`
- `services/web-ui-go/DEVELOPMENT_PLAN.md`
- `services/web-ui-go/LOGGING_RUNBOOK.md`
- `services/hsm-service/internal/server/logger.go`
- `services/cts-core/internal/logger/logger.go`

---

## 8) Change Policy for This File

This is the only root logging document.
- Add new logging decisions here first
- Reflect status changes here first
- Keep service plans as implementation detail, this file as canonical summary
