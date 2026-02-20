# CT-SYSTEM Testing Strategy

**Дата:** 2026-02-20
**Область:** `cts-core`, `hsm-service`, `web-ui-go`, `trader`, инфраструктура `docker compose`

---

## 1. Ключевой принцип

Для CT-SYSTEM корректно разделять проверки на 3 уровня:

1. **Service-local (без внешних систем)**
   - unit tests
   - package/component tests
   - сборка бинарника
2. **Service-integration (с минимальными зависимостями)**
   - сервис + только критичные sidecar зависимости
3. **System E2E (полная связка)**
   - целевой сценарий через все компоненты

Полноценные интеграционные тесты «каждого сервиса совсем в одиночку» **не всегда возможны по архитектуре**, и это нормально.

---

## 2. Матрица тестов по сервисам

| Service | Service-local | Minimal integration | Full-system E2E |
|---|---|---|---|
| HSM | ✅ Да | ✅ Да (может работать изолированно) | ✅ Да |
| Web-UI | ✅ Да | ✅ Да (требует MySQL) | ✅ Да |
| CTS-Core | ✅ Да | ✅ Да (требует MySQL + HSM) | ✅ Да |
| Trader | ✅ Да | ⚠️ Ограничено (зависит от DB/CTS-Core, container path пока требует донастройки) | ✅ Да |

---

## 3. Минимальные зависимости для integration

### HSM
- Минимум: нет обязательных внешних сервисов для базовой интеграции API.
- Проверки:
  - health endpoint
  - encrypt/decrypt round-trip
  - audit/access/error logs

### Web-UI
- Минимум: `mysql`.
- Почему: Web-UI подключается к БД при старте.
- Проверки:
  - запуск контейнера
  - `/login` доступен
  - auth/access/audit/error logging

### CTS-Core
- Минимум: `mysql` + `hsm`.
- Почему: startup/flows используют DB и HSM.
- Проверки:
  - health/ready/live
  - базовый HSM flow
  - access/error/audit logs

### Trader
- Минимум: обычно DB + оркестратор/внешние интеграции.
- Текущее ограничение в репозитории CT-SYSTEM:
  - сервисные блоки trader в root compose закомментированы
  - требуется синхронизация контейнерной конфигурации trader для стабильного integration запуска

---

## 4. Практические test-пайплайны

## 4.1 Service-local (быстрый контур)

### Web-UI
```bash
cd services/web-ui-go
go test ./...
go build ./...
```

### CTS-Core
```bash
cd services/cts-core
go test ./...
go build ./...
```

### HSM
```bash
cd services/hsm-service
go test ./...
go build ./...
```

### Trader
```bash
cd services/trader
go test ./...
go build ./...
```

---

## 4.2 Minimal integration (docker)

### HSM-only integration
```bash
docker compose up -d hsm
docker compose ps hsm
docker compose logs --since 2m hsm
```

### Web-UI + MySQL integration
```bash
docker compose up -d mysql web-ui
docker compose ps mysql web-ui
curl -sSI http://127.0.0.1/login | head -n 20
docker logs --since 2m ct-system-web-ui | tail -n 50
```

### CTS-Core + MySQL + HSM integration
```bash
docker compose up -d mysql hsm cts-core
docker compose ps mysql hsm cts-core
curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/ready
docker logs --since 2m ct-system-cts-core | tail -n 80
```

---

## 4.3 Full-system E2E

```bash
docker compose up -d
make ps
make health
make logs
```

Цели E2E:
- межсервисные связи стабильны
- ключевые API доступны
- request correlation (`request_id`) в логах
- ротация и запись логов в контейнерах

---

## 5. Что проверяем обязательно (quality gates)

### Gate A — Build
- каждый сервис собирается (`go build ./...`)

### Gate B — Runtime start
- сервис стартует в expected dependency topology
- health/readiness не деградируют

### Gate C — Logging/observability
- логи в `docker logs` не пустые
- формат JSON для production profile
- request-bound события содержат `request_id`
- для Web-UI присутствуют `access.log`, `error.log`, `audit.log`

### Gate D — Security baseline
- сервисы запускаются non-root (где внедрено)
- writable bind-mount paths ограничены безопасными правами

---

## 6. Ответ на архитектурный вопрос

### Можно ли делать интеграционные тесты каждой системы строго по одиночке?

- **HSM:** чаще всего да.
- **Web-UI / CTS-Core / Trader:** нет, не в полном смысле, потому что есть архитектурные runtime зависимости.

Это **не анти-паттерн** для distributed system. Норма — иметь 3 уровня тестов (local / minimal integration / full E2E).

---

## 7. Ближайшие улучшения testing в CT-SYSTEM

1. Добавить `make test-web-ui`, `make test-cts-core`, `make test-hsm`, `make test-trader` (service-local)
2. Добавить `make test-int-web-ui`, `make test-int-cts-core` (minimal integration)
3. Вынести smoke-check scripts в `scripts/testing/`
4. Для trader: завершить container wiring в root compose (если нужен integration в CT-SYSTEM)

---

## 8. Минимальная рекомендуемая CI-последовательность

1. `go test` + `go build` по сервисам
2. `docker compose build` обязательных сервисов
3. Minimal integration:
   - `mysql + web-ui`
   - `mysql + hsm + cts-core`
4. (Опционально nightly) full-system E2E

---

Этот документ — базовый testing-контракт для CT-SYSTEM и должен обновляться при изменении runtime-зависимостей сервисов.
