# TEMP: Config Parameters Unification TODO

Статус: **временный рабочий документ** для поэтапной реализации полного функционала параметров конфигурации.

Цель:
- унифицировать структуру параметров между `hsm-service`, `cts-core`, `web-ui-go`;
- довести каждый параметр до полного рабочего цикла: `schema -> validation -> runtime usage -> env override -> docs -> tests`.

---

## 0) Target unified schema (ориентир)

```yaml
server:
  port: 8443
  tls:
    enabled: true
    cert_path: "..."
    key_path: "..."
    ca_path: "..."
  timeouts:
    read: 30s
    write: 30s
    idle: 120s
    read_header: 5s
    shutdown_grace: 10s
  limits:
    max_header_bytes: 1048576
  http2:
    max_concurrent_streams: "1000"
    initial_window_size: "2M"
    max_frame_size: "1M"
    max_header_list_size: "1M"
    idle_timeout_seconds: 120
    max_upload_buffer_per_conn: "2M"
    max_upload_buffer_per_stream: "2M"

rate_limit:
  login:
    requests_per_minute: 5
    burst: 5
  api:
    requests_per_second: 100
    burst: 20
```

Примечание: в сервисах, где часть параметров не нужна, поле может быть опциональным, но **имя и место в схеме** должны оставаться едиными.

---

## 1) `server.tls.enabled`

### Текущее состояние
- `hsm-service`: нет `enabled` (TLS обязателен).
- `cts-core`: есть `server.tls.enabled`.
- `web-ui-go`: есть `server.tls.enabled`.

### Рекомендация
- Сохранить `server.tls.enabled` в `cts-core` и `web-ui-go`.
- Для `hsm-service` оставить TLS mandatory (без флага), т.к. это security boundary.

### TODO (полный функционал)
- [x] Явно задокументировать policy: почему в HSM нет `enabled`.
- [x] Для `cts-core` и `web-ui-go`: тесты на оба режима (`enabled=true/false`).
- [x] Добавить smoke-check на startup log (`tls_enabled`).

### Критерий готовности
- Конфиг, валидация и runtime корректно работают в двух режимах (`true/false`) для `cts-core`/`web-ui-go`.

---

## 2) `server.tls.cert_path` / `key_path` / `ca_path`

### Текущее состояние
- Все 3 сервиса используют одинаковые имена полей (`cert_path`, `key_path`, `ca_path`).
- В `web-ui-go` добавлены поля и runtime TLS запуск.

### Рекомендация
- Сохранить текущие имена и расположение.
- `ca_path` в `web-ui-go` пока как reserved (или подготовка к mTLS/verify chain).

### TODO (полный функционал)
- [x] В `web-ui-go`: определить и задокументировать поведение `ca_path` (используется/не используется).
- [x] Во всех сервисах: единый формат ошибок валидации при пустых путях.
- [x] Добавить negative tests: отсутствует cert/key при `enabled=true`.

### Критерий готовности
- Предсказуемые ошибки валидации и единый DX по TLS путям во всех сервисах.

---

## 3) `server.timeouts.*` (read/write/idle/read_header/shutdown_grace)

### Текущее состояние
- Во всех трех сервисах используется единая структура `server.timeouts.read/write/idle/read_header/shutdown_grace`.
- Таймауты берутся из конфига и покрыты defaults/validation.

### Рекомендация
- Унифицировать на структуру `server.timeouts.*` во всех сервисах.
- Добавить `read_header` и `shutdown_grace` минимум для `cts-core` и `web-ui-go`.

### TODO (полный функционал)
- [x] `web-ui-go`: миграция на `timeouts.read/write`.
- [x] `web-ui-go`: добавить `timeouts.idle`, `timeouts.read_header`, `timeouts.shutdown_grace`.
- [x] `cts-core`: добавить `timeouts.read_header`, `timeouts.shutdown_grace`.
- [x] `hsm-service`: вынести текущие hardcoded timeout в `server.timeouts.*`.
- [x] Везде добавить defaults + validation (`>0`, верхние границы).
- [x] Обновить docs/examples/tests по новым ключам.

### Критерий готовности
- Все HTTP timeout-параметры читаются из конфига, не хардкожены, и одинаково называются.

---

## 4) `server.limits.max_header_bytes`

### Текущее состояние
- Во всех трех сервисах добавлен `server.limits.max_header_bytes`.
- Значение применяется в `http.Server.MaxHeaderBytes` и покрыто тестами.

### Рекомендация
- Добавить единый параметр `server.limits.max_header_bytes` в 3 сервиса.

### TODO (полный функционал)
- [x] Добавить поле в schema/config loaders.
- [x] Проставить default `1048576` (1MB).
- [x] Валидация (`>= 4096`, разумный верхний предел).
- [x] Подключить к `http.Server.MaxHeaderBytьжзпes`.
- [x] Добавить тест на применение значения.

### Критерий готовности
- Ограничение заголовков регулируется только конфигом и одинаково работает везде.

---

## 5) `server.http2.*`

### Текущее состояние
- `hsm-service`: есть расширенный `server.http2` + parser/validation.
- `cts-core`: добавлен опциональный `server.http2` + parser/validation + runtime wiring.
- `web-ui-go`: добавлен опциональный `server.http2` + parser/validation + runtime wiring.

### Рекомендация
- Добавить `server.http2` как **опциональный** блок в `cts-core` и `web-ui-go`.
- Не копировать сразу агрессивные HSM значения как дефолт.

### TODO (полный функционал)
- [x] Вынести общую модель `HTTP2Config` (или продублировать минимально для старта).
- [x] Добавить parser size-форматов (`k/m`) + безопасные лимиты.
- [x] Подключить `http2.ConfigureServer` при наличии блока.
- [x] ENV overrides не требуются в текущем scope.
- [x] Тесты: parse + invalid values + startup integration.
- [x] Отдельный runbook не требуется в текущем scope.

### Критерий готовности
- HTTP/2 включается и тюнится параметрами одинакового имени во всех сервисах (где применимо).

---

## 6) `rate_limit.*` (где должно жить)

### Текущее состояние
- `hsm-service`: top-level `rate_limit.requests_per_second/burst`.
- `cts-core`: top-level `rate_limit.rest/websocket`, но фактическое применение ограничено/неочевидно.
- `web-ui-go`: rate limit в `security.rate_limit_login` и `security.rate_limit_api`.

### Вывод
`rate_limit` логически относится к **политике обработки запросов приложения**, а не к transport-настройкам `server`.

### Рекомендация
- Унифицировать размещение в top-level `rate_limit` (не внутри `server`, не внутри `security`).
- Для `web-ui-go` вынести `security.rate_limit_*` -> `rate_limit.login/api`.

### TODO (полный функционал)
- [x] `web-ui-go`: schema migration на `rate_limit.login/api` + runtime middleware wiring.
- [x] `cts-core`: ревизия текущего `rate_limit` и явное подключение middleware (REST/WS).
- [x] `hsm-service`: оставить `rate_limit` top-level, при необходимости расширить под per-endpoint.
- [x] Упростить целевой формат (без `*.global.*`):
  - [x] `rate_limit.login.requests_per_minute`
  - [x] `rate_limit.login.burst`
  - [x] `rate_limit.api.requests_per_second`
  - [x] `rate_limit.api.burst`
- [x] Документация и примеры для затронутых сервисов (`web-ui-go`, `cts-core`) обновлены.

### Критерий готовности
- Во всех сервисах `rate_limit` находится в одном месте схемы и реально применяется middleware.

---

## 7) Порядок реализации (рекомендуемый)

1. `server.timeouts` унификация (низкий риск, высокая ценность).
2. `server.limits.max_header_bytes` (безопасность + предсказуемость).
3. `rate_limit` relocation в `web-ui-go` + явный wiring в `cts-core`.
4. `server.http2` в `web-ui-go` (опционально, консервативные defaults).
5. `server.http2` в `cts-core` (после замеров).

---

## 8) Definition of Done для каждого параметра

Для каждого параметра изменение считается завершенным только если есть:
- [ ] Поле в config schema.
- [ ] Валидация + default.
- [ ] Реальное использование в runtime.
- [ ] Обновленные `config.yaml` и `config.example.yaml`.
- [ ] Обновленная документация (`*.md`).
- [ ] Unit/integration тесты.

---

## 9) Notes

- HSM security model (mandatory TLS + mTLS) не размывать ради «полной симметрии».
- Унификация должна быть по **названиям и расположению ключей**, а не по одинаковым default-значениям.
- Для HTTP/2 тюнинга использовать отдельные нагрузочные профили на сервис.

---

## 10) `web-ui-go` dual-mode: direct и behind nginx

Цель: поддержать два режима без форков кода:
- **Direct mode**: клиент → `web-ui-go`.
- **Proxy mode**: клиент → `nginx` (TLS + HTTP/2 + static) → `web-ui-go`.

Deployment note:
- **Dev (Docker)**: `nginx` отдельным контейнером рядом с `web-ui-go`.
- **Prod (Debian VM)**: `nginx + web-ui-go` на одной VM, отдельными процессами/сервисами.

### 10.1 Новая секция config для `web-ui-go`

Целевая схема:

```yaml
proxy:
  enabled: false
  trust_forward_headers: false
  trusted_hops: 1
  trusted_cidrs:
    - "127.0.0.1/32"
    - "10.0.0.0/8"
  static_via_nginx: false
```

TODO:
- [x] Добавить `proxy.*` в schema/config loader (`web-ui-go`).
- [x] Defaults/validation:
  - [x] `enabled=false`
  - [x] `trust_forward_headers=false`
  - [x] `trusted_hops>=1 && <=5`
  - [x] Валидация CIDR списка
- [x] Runtime-поведение:
  - [x] При `proxy.enabled=true` и `static_via_nginx=true` не регистрировать `r.Static("/assets", ...)` в Gin.
  - [x] При `proxy.enabled=true` включить обработку `X-Forwarded-Proto`, `X-Forwarded-For`, `X-Forwarded-Host` только от trusted источников.
  - [x] При `proxy.enabled=true` не ломать existing `session_cookie_secure` логику: secure должен считаться true при внешнем HTTPS (через `X-Forwarded-Proto=https`).
  - [x] `request_id` обязателен: если пришел `X-Request-ID` — использовать его; если нет — генерировать.
  - [x] Всегда прокидывать `X-Request-ID` в ответ клиенту и во все downstream запросы.
    - Добавлен helper в `web-ui-go`: `middleware.NewRequestWithRequestID(...)` + unit tests.
    - Требование для новых исходящих HTTP-вызовов: использовать этот helper (или `SetRequestIDHeaderFromContext`).

### 10.2 Что остается нужным из `server.*`

Даже в proxy mode сохраняем:
- [ ] `server.port` (апстрим-порт внутри сети).
- [ ] `server.timeouts.*` (защита апстрима от зависающих клиентов/соединений).
- [ ] `server.limits.max_header_bytes` (ограничение заголовков на backend).

Conditional usage:
- [ ] `server.tls.*`: опционально, обычно `enabled=false` при TLS-терминации на nginx.
- [ ] будущий `server.http2.*` для `web-ui-go`: можно не использовать в proxy mode (HTTP/2 обслуживает nginx).

### 10.3 Docker Compose доработки

TODO:
- [ ] Добавить сервис `nginx` в основной `docker-compose.yml`:
  - [ ] `depends_on: web-ui-go`
  - [ ] публикация `443:443` (и опционально `80:80` для redirect)
  - [ ] volume mount для `nginx.conf`, cert/key, статических ассетов
- [ ] Внутренняя сеть:
  - [ ] `nginx` ↔ `web-ui-go` по private network
  - [ ] `web-ui-go` наружу не публиковать в proxy profile
- [ ] Добавить compose profiles:
  - [ ] `direct` (без nginx)
  - [ ] `proxy` (с nginx)
- [ ] Healthchecks:
  - [ ] `web-ui-go` health endpoint
  - [ ] `nginx` health endpoint

### 10.4 Nginx config (HTTP/2 + high-load profile)

TODO:
- [ ] Добавить `services/nginx/` (или `infra/nginx/`) с файлами:
  - [ ] `nginx.conf`
  - [ ] `conf.d/web-ui.conf`
  - [ ] `README.md`
- [ ] TLS + HTTP/2 на `listen 443 ssl http2;`
- [ ] Агрессивный (но безопасный) профиль для high-load:
  - [ ] `worker_processes auto;`
  - [ ] `worker_connections` и `worker_rlimit_nofile`
  - [ ] `keepalive_timeout`, `keepalive_requests`
  - [ ] `sendfile on`, `tcp_nopush on`, `tcp_nodelay on`
  - [ ] `client_header_timeout`, `client_body_timeout`, `send_timeout`
  - [ ] `client_max_body_size` (явно)
  - [ ] upstream keepalive к `web-ui-go`
  - [ ] `proxy_http_version 1.1`, `proxy_set_header Connection ""`
  - [ ] `proxy_read_timeout`, `proxy_send_timeout`, `proxy_connect_timeout`
- [ ] Статика:
  - [ ] `location /assets/` с `root/alias`, `expires`, `cache-control`, `etag`
  - [ ] `gzip`/`brotli` (если модуль доступен)

### 10.5 Security/Correctness за reverse proxy

TODO:
- [ ] Trusted proxy policy: не доверять `X-Forwarded-*` от внешних клиентов напрямую.
- [ ] Добавить middleware/helper для вычисления effective scheme/ip/host.
- [ ] Корреляция логов: `request_id` должен совпадать в логах `nginx` и `web-ui-go`.
- [ ] Проверить редиректы и абсолютные URL (чтобы не было mixed content / loop).
- [ ] Логи: отделить `remote_addr` (nginx) и `real_ip` (клиент).
- [ ] Обновить CSP/HSTS policy в контексте TLS termination на edge.

### 10.6 Tests/Runbook/Docs

TODO:
- [x] Unit tests для `proxy.*` validation.
- [ ] Integration tests (минимум smoke):
  - [ ] direct mode: static отдает Gin
  - [ ] proxy mode: static отдает nginx, Gin static отключен
  - [ ] proxy mode: secure-cookie при `X-Forwarded-Proto=https`
  - [ ] proxy mode: `X-Request-ID` не теряется на пути `client -> nginx -> web-ui-go -> response`
- [ ] Документация:
  - [ ] `web-ui-go/config/README.md` (новая секция `proxy`)
  - [ ] root `README.md` (как запускать `direct`/`proxy` profile)
  - [ ] troubleshooting по forwarded headers

### 10.7 Definition of Done для dual-mode

- [ ] Один и тот же бинарник `web-ui-go` работает в двух режимах только через конфиг/profile.
- [ ] В proxy mode TLS/HTTP2/статика обслуживаются nginx, backend работает как защищенный апстрим.
- [ ] Нет регрессий по cookies, auth, audit/access logs, graceful shutdown.
- [ ] Документация и примеры конфигов синхронизированы во всех `*.md`.
