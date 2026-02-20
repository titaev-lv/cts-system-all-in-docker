# PKI Infrastructure Plan

> **Цель**: Автоматическая генерация PKI инфраструктуры для dev-окружения CT-System
> **Дата**: 2026-02-02
> **Статус**: План разработки

---

## 📋 Обзор задачи

### Текущая ситуация
- В hsm-service есть скрипты для генерации сертификатов (pki/scripts/*)
- Каждый сервис требует mTLS для безопасной коммуникации
- Сертификаты сейчас создаются вручную
- Нет централизованного управления PKI

### Цель
Автоматизировать:
1. Установку проектов из GitHub (`init-system.sh`)
2. Генерацию dev CA и всех необходимых сертификатов
3. Правильное монтирование PKI в docker-compose
4. Поддержку 3 экземпляров trader

---

## 🏗️ Архитектура PKI

### Структура директорий

```
volumes/
└── pki/
    ├── ca/                          # Root CA (общий для всех)
    │   ├── ca.key                   # CA приватный ключ
    │   ├── ca.crt                   # CA сертификат
    │   └── ca.srl                   # Serial number file
    │
    ├── mysql/                       # MySQL Server
    │   ├── server/
    │   │   ├── mysql.key
    │   │   ├── mysql.crt
    │   │   └── mysql.ext
    │   └── clients/
    │       ├── web-ui/              # Web UI → MySQL
    │       │   ├── mysql-client.key
    │       │   └── mysql-client.crt
    │       └── cts-core/            # CTS-Core → MySQL
    │           ├── mysql-client.key
    │           └── mysql-client.crt
    │
    ├── clickhouse/                  # ClickHouse Server (будущее)
    │   ├── server/
    │   │   ├── clickhouse.key
    │   │   ├── clickhouse.crt
    │   │   └── clickhouse.ext
    │   └── clients/
    │       ├── web-ui/              # Web UI → ClickHouse
    │       ├── trader-1/            # Trader-1 → ClickHouse
    │       ├── trader-2/            # Trader-2 → ClickHouse
    │       └── trader-3/            # Trader-3 → ClickHouse
    │
    ├── hsm-service/                 # HSM Service Server
    │   ├── server/
    │   │   ├── hsm-service.key
    │   │   ├── hsm-service.crt
    │   │   └── hsm-service.ext
    │   └── clients/
    │       ├── web-ui-2fa/          # Web UI → HSM (OU=2FA)
    │       │   ├── hsm-client.key
    │       │   └── hsm-client.crt
    │       ├── cts-core-2fa/        # CTS-Core → HSM (OU=2FA)
    │       │   ├── hsm-client.key
    │       │   └── hsm-client.crt
    │       ├── cts-core-trader/     # CTS-Core → HSM (OU=Trader)
    │       │   ├── hsm-client.key
    │       │   └── hsm-client.crt
    │       ├── trader-1/            # Trader-1 → HSM (OU=Trader)
    │       │   ├── hsm-client.key
    │       │   └── hsm-client.crt
    │       ├── trader-2/            # Trader-2 → HSM (OU=Trader)
    │       │   ├── hsm-client.key
    │       │   └── hsm-client.crt
    │       └── trader-3/            # Trader-3 → HSM (OU=Trader)
    │           ├── hsm-client.key
    │           └── hsm-client.crt
    │
    └── cts-core/                    # CTS-Core Server
        ├── server/
        │   ├── cts-core.key
        │   ├── cts-core.crt
        │   └── cts-core.ext
        └── clients/
            ├── web-ui/              # Web UI → CTS-Core
            │   ├── cts-client.key
            │   └── cts-client.crt
            ├── trader-1/            # Trader-1 → CTS-Core
            │   ├── cts-client.key
            │   └── cts-client.crt
            ├── trader-2/            # Trader-2 → CTS-Core
            │   ├── cts-client.key
            │   └── cts-client.crt
            └── trader-3/            # Trader-3 → CTS-Core
                ├── cts-client.key
                └── cts-client.crt
```

---

## 📊 Матрица сертификатов

### Серверные сертификаты (4 штуки)

| № | Сервис | CN | SAN DNS | SAN IP | Описание |
|---|--------|----|---------|---------| ---------|
| 1 | MySQL | mysql | mysql,ct-system-mysql,localhost | 127.0.0.1 | База данных |
| 2 | ClickHouse | clickhouse | clickhouse,ct-system-clickhouse,localhost | 127.0.0.1 | Аналитическая БД (будущее) |
| 3 | HSM Service | hsm-service | hsm,hsm-service,ct-system-hsm,localhost | 127.0.0.1 | Криптографический сервис |
| 4 | CTS-Core | cts-core | cts-core,ct-system-cts-core,localhost | 127.0.0.1 | Центральный оркестратор |

### Клиентские сертификаты (19 штук)

| № | Клиент | Сервер | CN | OU | Описание |
|---|--------|--------|----|----|----------|
| 1 | Web UI | MySQL | web-ui-mysql-client | Database | Web UI доступ к MySQL |
| 2 | CTS-Core | MySQL | cts-core-mysql-client | Database | CTS-Core доступ к MySQL |
| 3 | Web UI | HSM | web-ui-hsm-2fa | 2FA | Web UI шифрование 2FA секретов |
| 4 | CTS-Core | HSM | cts-core-hsm-2fa | 2FA | CTS-Core шифрование 2FA |
| 5 | CTS-Core | HSM | cts-core-hsm-trader | Trader | CTS-Core шифрование ключей бирж |
| 6 | Trader-1 | HSM | trader-1-hsm-client | Trader | Trader-1 расшифровка API ключей |
| 7 | Trader-2 | HSM | trader-2-hsm-client | Trader | Trader-2 расшифровка API ключей |
| 8 | Trader-3 | HSM | trader-3-hsm-client | Trader | Trader-3 расшифровка API ключей |
| 9 | Web UI | ClickHouse | web-ui-clickhouse-client | Database | Web UI доступ к ClickHouse |
| 10 | Trader-1 | ClickHouse | trader-1-clickhouse-client | Database | Trader-1 запись tick data |
| 11 | Trader-2 | ClickHouse | trader-2-clickhouse-client | Database | Trader-2 запись tick data |
| 12 | Trader-3 | ClickHouse | trader-3-clickhouse-client | Database | Trader-3 запись tick data |
| 13 | Web UI | CTS-Core | web-ui-cts-client | Admin | Web UI управление системой |
| 14 | Trader-1 | CTS-Core | trader-1-cts-client | Trader | Trader-1 регистрация и задания |
| 15 | Trader-2 | CTS-Core | trader-2-cts-client | Trader | Trader-2 регистрация и задания |
| 16 | Trader-3 | CTS-Core | trader-3-cts-client | Trader | Trader-3 регистрация и задания |

**Итого**: 4 серверных + 16 клиентских = **20 сертификатов**

*(Примечание: Вы указали 16 клиентских, но с учётом ClickHouse их получается 16)*

---

## 🔧 Реализация

### Phase 1: Структура и скрипты

#### 1.1 Создать структуру директорий
```bash
volumes/pki/
├── ca/
├── mysql/server/
├── mysql/clients/{web-ui,cts-core}/
├── clickhouse/server/
├── clickhouse/clients/{web-ui,trader-1,trader-2,trader-3}/
├── hsm-service/server/
├── hsm-service/clients/{web-ui-2fa,cts-core-2fa,cts-core-trader,trader-1,trader-2,trader-3}/
└── cts-core/server/
└── cts-core/clients/{web-ui,trader-1,trader-2,trader-3}/
```

#### 1.2 Скрипты PKI
- `scripts/pki/01-generate-ca.sh` - Генерация Root CA
- `scripts/pki/02-generate-server-certs.sh` - Все серверные сертификаты
- `scripts/pki/03-generate-client-certs.sh` - Все клиентские сертификаты
- `scripts/pki/helpers.sh` - Общие функции

### Phase 2: init-system.sh скрипт

```bash
#!/bin/bash
# CT-System Initialization Script

1. Проверка prerequisites (Docker, docker-compose, Git)
2. Клонирование GitHub репозиториев:
   - git clone <hsm-service-url> services/hsm-service
   - git clone <cts-core-url> services/cts-core
  - git clone <trader-url> services/trader
   - git clone <web-ui-go-url> services/web-ui-go
3. Копирование .env.example → .env
4. Генерация PKI инфраструктуры:
   - ./scripts/pki/01-generate-ca.sh
   - ./scripts/pki/02-generate-server-certs.sh
   - ./scripts/pki/03-generate-client-certs.sh
5. Инициализация конфигураций сервисов
6. docker compose up -d
7. Проверка health checks
```

### Phase 3: docker-compose.yml обновления

**Монтирование для каждого сервиса:**

```yaml
mysql:
  volumes:
    - ./volumes/pki/ca/ca.crt:/etc/mysql/ssl/ca.crt:ro
    - ./volumes/pki/mysql/server/mysql.key:/etc/mysql/ssl/server.key:ro
    - ./volumes/pki/mysql/server/mysql.crt:/etc/mysql/ssl/server.crt:ro

hsm-service:
  volumes:
    - ./volumes/pki/ca/ca.crt:/app/pki/ca/ca.crt:ro
    - ./volumes/pki/hsm-service/server/hsm-service.key:/app/pki/server/server.key:ro
    - ./volumes/pki/hsm-service/server/hsm-service.crt:/app/pki/server/server.crt:ro

cts-core:
  volumes:
    - ./volumes/pki/ca/ca.crt:/app/pki/ca/ca.crt:ro
    - ./volumes/pki/cts-core/server/cts-core.key:/app/pki/server/server.key:ro
    - ./volumes/pki/cts-core/server/cts-core.crt:/app/pki/server/server.crt:ro
    - ./volumes/pki/mysql/clients/cts-core/mysql-client.key:/app/pki/mysql/client.key:ro
    - ./volumes/pki/mysql/clients/cts-core/mysql-client.crt:/app/pki/mysql/client.crt:ro
    - ./volumes/pki/hsm-service/clients/cts-core-2fa/hsm-client.key:/app/pki/hsm/2fa/client.key:ro
    - ./volumes/pki/hsm-service/clients/cts-core-2fa/hsm-client.crt:/app/pki/hsm/2fa/client.crt:ro
    - ./volumes/pki/hsm-service/clients/cts-core-trader/hsm-client.key:/app/pki/hsm/trader/client.key:ro
    - ./volumes/pki/hsm-service/clients/cts-core-trader/hsm-client.crt:/app/pki/hsm/trader/client.crt:ro

web-ui:
  volumes:
    - ./volumes/pki/ca/ca.crt:/app/pki/ca/ca.crt:ro
    - ./volumes/pki/mysql/clients/web-ui/mysql-client.key:/app/pki/mysql/client.key:ro
    - ./volumes/pki/mysql/clients/web-ui/mysql-client.crt:/app/pki/mysql/client.crt:ro
    - ./volumes/pki/hsm-service/clients/web-ui-2fa/hsm-client.key:/app/pki/hsm/client.key:ro
    - ./volumes/pki/hsm-service/clients/web-ui-2fa/hsm-client.crt:/app/pki/hsm/client.crt:ro
    - ./volumes/pki/cts-core/clients/web-ui/cts-client.key:/app/pki/cts-core/client.key:ro
    - ./volumes/pki/cts-core/clients/web-ui/cts-client.crt:/app/pki/cts-core/client.crt:ro

trader-1:
  volumes:
    - ./volumes/pki/ca/ca.crt:/app/pki/ca/ca.crt:ro
    - ./volumes/pki/hsm-service/clients/trader-1/hsm-client.key:/app/pki/hsm/client.key:ro
    - ./volumes/pki/hsm-service/clients/trader-1/hsm-client.crt:/app/pki/hsm/client.crt:ro
    - ./volumes/pki/cts-core/clients/trader-1/cts-client.key:/app/pki/cts-core/client.key:ro
    - ./volumes/pki/cts-core/clients/trader-1/cts-client.crt:/app/pki/cts-core/client.crt:ro

# trader-2, trader-3 аналогично
```

---

## 🔐 Спецификация сертификатов

### Root CA
```bash
Subject: /C=RU/ST=Moscow/L=Moscow/O=CT-System-Dev/CN=CT-System-Dev-CA
Validity: 3650 days (10 лет для dev)
Key: RSA 4096
```

### Серверные сертификаты
```bash
Subject: /C=RU/ST=Moscow/L=Moscow/O=CT-System-Dev/OU=Services/CN=<service-name>
SAN: DNS:<service-name>,DNS:<container-name>,DNS:localhost,IP:127.0.0.1
Validity: 825 days (Apple/Google max lifetime)
Key: RSA 4096
Extensions:
  - keyUsage: critical, digitalSignature, keyEncipherment
  - extendedKeyUsage: serverAuth
```

### Клиентские сертификаты
```bash
Subject: /C=RU/ST=Moscow/L=Moscow/O=CT-System-Dev/OU=<context>/CN=<client-name>
OU values:
  - Database: для MySQL/ClickHouse клиентов
  - 2FA: для HSM 2FA контекста
  - Trader: для HSM Trader контекста
  - Admin: для административных клиентов
Validity: 825 days
Key: RSA 4096
Extensions:
  - keyUsage: critical, digitalSignature
  - extendedKeyUsage: clientAuth
```

---

## 📝 Чеклист реализации

### Скрипты
- [ ] `scripts/pki/helpers.sh` - общие функции
- [ ] `scripts/pki/01-generate-ca.sh` - Root CA
- [ ] `scripts/pki/02-generate-server-certs.sh` - 4 серверных сертификата
- [ ] `scripts/pki/03-generate-client-certs.sh` - 16 клиентских сертификатов
- [ ] `scripts/pki/clean-pki.sh` - очистка для пересоздания
- [ ] `init-system.sh` - главный скрипт инициализации

### Конфигурация
- [ ] Обновить `docker-compose.yml` с монтированием PKI
- [ ] Создать `.env.example` с переменными для GitHub URL
- [ ] Обновить `README.md` с инструкциями по установке
- [ ] Создать `docs/PKI_SETUP.md` - детальное описание PKI

### Тестирование
- [ ] Проверить генерацию CA
- [ ] Проверить генерацию всех серверных сертификатов
- [ ] Проверить генерацию всех клиентских сертификатов
- [ ] Проверить валидность SAN (curl без -k)
- [ ] Проверить mTLS соединения между сервисами
- [ ] Проверить HSM ACL по OU

---

## 🚀 План выполнения

### Этап 1: Подготовка (1 час)
1. Создать директорию `scripts/pki/`
2. Скопировать базовые функции из `services/hsm-service/pki/scripts/`
3. Адаптировать для новой структуры `volumes/pki/`

### Этап 2: Генерация PKI (2 часа)
1. Разработать `01-generate-ca.sh`
2. Разработать `02-generate-server-certs.sh`
3. Разработать `03-generate-client-certs.sh`
4. Тестирование на чистой системе

### Этап 3: init-system.sh (1 час)
1. Разработать логику клонирования GitHub репозиториев
2. Интеграция вызова PKI скриптов
3. Проверка prerequisites
4. Инициализация docker-compose

### Этап 4: Интеграция (1-2 часа)
1. Обновить `docker-compose.yml`
2. Обновить конфигурации сервисов (config.yaml в каждом сервисе)
3. Документация

### Этап 5: Тестирование (1 час)
1. Полное тестирование на чистой системе
2. Проверка curl без -k
3. Проверка логов mTLS

**Общее время**: ~6-7 часов

---

## ⚠️ Важные замечания

### GitHub репозитории
- **Проблема**: ct-system (корневой проект) не в GitHub
- **Решение**: В `install.sh` предусмотреть сценарий, когда ct-system уже существует (пользователь клонирует вручную)
- **Рекомендация**: Добавить ct-system в GitHub для полной автоматизации

### Docker network DNS
- Все SAN должны включать имена контейнеров из docker-compose
- Использовать сетевые алиасы если требуется (уже есть `hsm-service` alias)

### Security Best Practices
- Все `.key` файлы с правами 600
- CA private key особо защищён (600, root:root)
- Volume mount как `:ro` (read-only) везде где возможно

### Production vs Dev
- **Dev**: Автогенерация PKI, self-signed CA, 10 лет lifetime для CA
- **Production**: Использовать корпоративный CA, короткие lifetime, автоматическая ротация

### Production PKI Management Challenge

**Проблема:**
В production окружении CA находится на отдельной изолированной машине (air-gapped или с ограниченным доступом) и требует ввода пароля для использования приватного ключа. Это создаёт сложности:
- ❌ Невозможно автоматизировать генерацию сертификатов как в dev
- ❌ Каждый новый сертификат требует ручного вмешательства администратора
- ❌ Масштабирование (добавление новых trader инстансов) становится медленным
- ❌ Ротация сертификатов требует координации и ручной работы

**Требуется решение для упрощения:**
1. Генерации сертификатов в production (с изолированным CA)
2. Управления lifecycle сертификатов (renewal, revocation)
3. Аудита выпущенных сертификатов
4. Автоматизации где возможно, но с сохранением безопасности

**Возможные подходы:**

**Вариант 1: Intermediate CA на app-серверах**
```
Root CA (offline, password-protected)
    └── Intermediate CA (online, HSM-protected)
        └── End-entity certificates (auto-issue)
```
- ✅ Root CA остаётся изолированным
- ✅ Intermediate CA может автоматически выпускать сертификаты
- ✅ Компрометация Intermediate CA не скомпрометирует Root CA
- ❌ Нужно защищать Intermediate CA (HSM обязателен)

**Вариант 2: Certificate Management Tool**
```
HashiCorp Vault PKI или Step-CA:
- Централизованное управление PKI
- REST API для запроса сертификатов
- Автоматическая ротация
- Audit logging
- ACME protocol support
```
- ✅ Профессиональное решение
- ✅ Автоматизация + безопасность
- ✅ Готовая интеграция с Docker/K8s
- ❌ Дополнительная инфраструктура
- ❌ Learning curve

**Вариант 3: CSR-based workflow с scripts**
```bash
1. Сервис генерирует CSR локально
2. Admin получает CSR через secure channel
3. Admin подписывает на CA машине (с паролем)
4. Signed cert возвращается через secure channel
5. Сервис устанавливает подписанный сертификат
```
- ✅ Простота реализации
- ✅ Полный контроль администратора
- ❌ Ручной процесс для каждого сертификата
- ❌ Не масштабируется

**Рекомендация для Phase 2:**
- **Short-term**: CSR-based workflow со скриптами (Вариант 3)
  - Создать `scripts/pki/generate-csr.sh` для сервисов
  - Создать `scripts/pki/sign-csr.sh` для CA машины
  - Документировать процесс в PKI_PRODUCTION.md
  
- **Long-term**: Внедрить HashiCorp Vault или Step-CA (Вариант 2)
  - Полноценное PKI as a Service
  - Интеграция с monitoring/alerting
  - Автоматическая ротация перед истечением

**TODO**: Добавить в план разработки (Phase 2 или Phase 3):
- [ ] Спроектировать CSR workflow для production
- [ ] Создать скрипты для генерации CSR на сервисах
- [ ] Создать скрипты для подписания CSR на CA машине
- [ ] Документировать production PKI процедуры
- [ ] Исследовать Vault/Step-CA для долгосрочной перспективы

---

## 📚 Ссылки на документацию

- [HSM Service ARCHITECTURE.md](../services/hsm-service/ARCHITECTURE.md) - PKI infrastructure
- [HSM Service API.md](../services/hsm-service/API.md) - mTLS configuration
- [CTS-Core ARCHITECTURE.md](../services/cts-core/ARCHITECTURE.md) - Security requirements
- [MYSQL_SSL_SETUP.md](MYSQL_SSL_SETUP.md) - MySQL SSL configuration

---

## 🎯 Следующие шаги

1. ✅ План создан
2. ⏳ Создать базовые PKI скрипты
3. ⏳ Разработать init-system.sh
4. ⏳ Обновить docker-compose.yml
5. ⏳ Тестирование на dev окружении
6. ⏳ Документация обновлена

**Автор**: GitHub Copilot  
**Дата**: 2026-02-02
