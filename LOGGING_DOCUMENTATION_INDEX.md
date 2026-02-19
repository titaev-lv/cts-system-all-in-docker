# 📚 Logging Documentation Index

> **Date:** 2026-02-18  
> **Version:** 1.0  
> **Status:** Comprehensive audit and unification plan complete

---

## 📋 Document Structure

### System-Level Documents

1. **[LOGGING_ANALYSIS_DETAILED.md](LOGGING_ANALYSIS_DETAILED.md)**
   - 📊 **Type:** Detailed technical analysis
   - 📏 **Length:** 62 KB (comprehensive)
   - 🎯 **Audience:** Architects, Lead Engineers
   - **Content:**
     - Detailed comparison table for all 4 services
     - Service-by-service analysis (HSM, CTS-Core, Trader, Web UI)
     - Root cause analysis of problems
     - Unified standard requirements
     - Implementation checklist per service
     - Migration prioritization

   **When to use:**
   - Understanding the *why* behind each requirement
   - Comparing current vs target state
   - Planning the entire logging unification effort

2. **[LOGGING_QUICK_REFERENCE.md](LOGGING_QUICK_REFERENCE.md) ← START HERE**
   - 🔧 **Type:** Implementation guide
   - 📏 **Length:** 15 KB (concise)
   - 🎯 **Audience:** Developers implementing fixes
   - **Content:**
     - Quick at-a-glance comparison
     - Step-by-step fixes for each service
     - Copy-paste code examples
     - Validation checklists
     - Quick commands for testing

   **When to use:**
   - Implementing logging fixes
   - Need concrete code examples
   - Need step-by-step instructions

---

### Service-Specific Documents

#### CTS-Core
- **[services/cts-core/DEVELOPMENT_PLAN.md](services/cts-core/DEVELOPMENT_PLAN.md#3-unifikacija-logirovanija)**
  - Section: "3. 📊 Унификация логирования"
  - Changes needed: WS protocol + graceful shutdown
  - Effort: 1-2 days
  - Impact: MEDIUM (observability improvements)

#### Trader Daemon
- **[services/trader-daemon/DEVELOPMENT_PLAN.md](services/trader-daemon/DEVELOPMENT_PLAN.md#-kritichno-unifikacija-logirovanija)**
  - Section: "🔴 КРИТИЧНО: Унификация логирования"
  - Changes needed: Identical to CTS-Core
  - Effort: 0.5 days
  - Impact: HIGH (enables docker logs)

#### Web UI (Go)
- **[services/web-ui-go/DEVELOPMENT_PLAN.md](services/web-ui-go/DEVELOPMENT_PLAN.md#-kritichno-unifikacija-logirovanija)**
  - Section: "🔴 КРИТИЧНО: Унификация логирования"
  - Changes needed: legacy logger → slog + access.log/error.log split
  - Effort: 2-3 days
  - Impact: HIGH (migration + new features)

#### HSM Service
- **[services/hsm-service/DEVELOPMENT_PLAN.md](services/hsm-service/DEVELOPMENT_PLAN.md#-unifikacija-logirovanija)**
  - Section: "📊 Унификация логирования"
  - Status: ✅ REFERENCE IMPLEMENTATION (v2.0.0)
  - Notes: audit/access/error split, request_id, fail-fast log checks, graceful shutdown, panic recovery

---

## 🎯 By Role

### 👨‍💼 Project Manager / Tech Lead
**Start here:**
1. [LOGGING_ANALYSIS_DETAILED.md](LOGGING_ANALYSIS_DETAILED.md) — Understand the scope
2. [CT-System DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md#11-unifikacija-logirovanija-2-3-dnja--) — See Priority 1 section
3. Summary: 2-3 days effort, HIGH impact on debugging capability

**Key metrics:**
- 3 services need logging fixes
- 1 critical (Trader no docker logs)
- 1 platform migration (Web UI: legacy logger → slog)
- 1 enhancement (Web UI: access log split)

### 👨‍💻 Developer (Implementing Fixes)
**Start here:**
1. [LOGGING_QUICK_REFERENCE.md](LOGGING_QUICK_REFERENCE.md) — Your task list
2. Service-specific DEVELOPMENT_PLAN.md — Detailed requirements
3. Reference: [services/hsm-service/internal/server/logger.go](services/hsm-service/internal/server/logger.go)

**Quick path:**
```
CTS-Core fix:    1-2 days    (WS protocol + graceful shutdown)
Trader fix:      30 minutes  (identical to CTS-Core)
Web UI fix:      2-3 days    (migration + features)
Testing:         1 day       (validation + docker logs checks)
```

### 🔬 QA / Quality Assurance
**Testing checklist:**
1. [LOGGING_QUICK_REFERENCE.md#-validation-checklist](LOGGING_QUICK_REFERENCE.md#-validation-checklist)
2. All services must pass:
   - [ ] `docker logs` shows output
   - [ ] Output is valid JSON
   - [ ] Module tags present (where applicable)
   - [ ] Log files exist and rotate

**Commands:**
```bash
docker logs ct-system-cts-core-1 | jq . | head
docker logs ct-system-trader-daemon-1 | jq . | head
docker logs ct-system-web-ui-1 | jq . | head
```

### 🏗️ Architect / Senior Engineer
**Review scope:**
1. [LOGGING_ANALYSIS_DETAILED.md](LOGGING_ANALYSIS_DETAILED.md) — Understand design decisions
2. [DEVELOPMENT_PLAN.md section 1.1](DEVELOPMENT_PLAN.md#11-unifikacija-logirovanija-2-3-dnja--) — Resource allocation
3. Key decisions:
   - ✅ slog (stdlib) over external deps
   - ✅ JSON format for aggregation tools
   - ✅ MultiWriter (stdout + file) for Docker
   - ✅ lumberjack (proven rotation logic)
   - ✅ Module tagging for service discovery

---

## 📊 Unified Logging Standard

### Summary Table

| Component | Standard | HSM | CTS-Core | Trader | Web UI |
|-----------|----------|-----|----------|--------|--------|
| **Library** | slog | ✅ | ✅ | ✅ | ❌→✅ |
| **Format** | JSON | ✅ | ✅ | ❌→✅ | ✅ |
| **Stdout** | Yes | ✅ | ✅ | ❌→✅ | ✅ |
| **Rotation** | lumberjack | ✅ | ✅ | ❌→✅ | ✅ |
| **Access log** | (Web UI only) | - | - | - | ✅ |
| **modules** | Yes | optional | ✅ | ✅ | ✅ |

### Standard Requirements

```json
{
  "logging": {
    "library": "log/slog (stdlib)",
    "format": "JSON",
    "output": "MultiWriter(stdout, file)",
    "rotation": {
      "type": "lumberjack",
      "max_size_mb": 100,
      "max_backups": 10,
      "max_age_days": 30,
      "compress": true
    },
    "module_support": true,
    "special_cases": {
      "web_ui": "split into access.log + error.log",
      "hsm_service": "split into audit.log + access.log + error.log",
      "cts_core": "split into error/access/out_request/ws_access/ws_out/audit"
    }
  }
}
```

---

## 🎯 Implementation Priority

### Priority 1: Critical (2-3 days)
- [ ] CTS-Core: WS protocol + graceful shutdown
- [ ] Trader: Add stdout + JSON (blocks docker logs debugging)
- [ ] Web UI: Migrate legacy logger → slog (external dependency removal)

### Priority 2: Scaling (1 day)
- [ ] Web UI: Add access.log split (new analytics capability)
- [ ] All services: Add write-access validation at startup

### Priority 3: Polish (0.5 days)
- [ ] Unified telemetry (Prometheus metrics integration)

---

## 📈 Expected Outcomes

### Before Implementation
```
$ docker logs ct-system-trader-daemon-1
<empty output>  ← PROBLEM: logs to file only, not stdout

$ cat /var/log/trader-daemon/error.log
2026-02-10 14:30:45 [main] Started  ← PROBLEM: not JSON, hard to parse
```

### After Implementation
```
$ docker logs ct-system-trader-daemon-1 | head -3 | jq .
{
  "time": "2026-02-10T14:30:45.123Z",
  "level": "INFO",
  "msg": "Started",
  "module": "main"
}  ← JSON format, easy to parse

$ docker logs ct-system-web-ui-1 | grep "method" | head
{"time":"2026-02-10T14:30:45Z","method":"POST","path":"/api/trades","status":201,...}

$ ls -lh /var/log/web-ui/
-rw-r--r--  1 app app  45M Feb 10 14:35 access.log
-rw-r--r--  1 app app  32M Feb 10 14:35 error.log
```

---

## 🔗 Related Documentation

- [CT-System DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) — Overall system roadmap
- [services/hsm-service/DEVELOPMENT_PLAN.md](services/hsm-service/DEVELOPMENT_PLAN.md) — HSM development
- [services/cts-core/DEVELOPMENT_PLAN.md](services/cts-core/DEVELOPMENT_PLAN.md) — CTS-Core development
- [services/web-ui-go/DEVELOPMENT_PLAN.md](services/web-ui-go/DEVELOPMENT_PLAN.md) — Web UI development
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — System architecture overview

---

## 🚀 Getting Started

### For developers
1. Read: [LOGGING_QUICK_REFERENCE.md](LOGGING_QUICK_REFERENCE.md)
2. Pick your task:
  - `CTS-Core request_id + access/out_request split` (1-2 days)
   - `Make Trader logs visible` (30 min)
   - `Migrate Web UI logging` (2-3 days)
3. Follow step-by-step instructions
4. Validate with provided checklists

### For architects
1. Read: [LOGGING_ANALYSIS_DETAILED.md](LOGGING_ANALYSIS_DETAILED.md)
2. Review: Service-specific DEV_PLAN sections
3. Plan resource allocation: 2-3 engineer-days total

### For QA
1. Review: [Validation Checklist](LOGGING_QUICK_REFERENCE.md#-validation-checklist)
2. Create test plan: All 4 services must pass checks
3. Regression testing: Ensure no log data loss

---

**Status:** 📋 Analysis complete, ready for implementation  
**Maintenance:** Update this index as new logging features are added
