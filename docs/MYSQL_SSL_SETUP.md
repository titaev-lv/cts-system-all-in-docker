# MySQL SSL Configuration

## Текущая конфигурация

MySQL настроен с поддержкой TLS/SSL:
- **Сервер:** Использует сертификаты из `services/mysql/pki/server/`
- **CA:** `services/mysql/pki/ca/ca.crt`
- **require_secure_transport:** Закомментирован (SSL опционален)

## Быстрый старт: Создание пользователя с SSL

### 1. Генерация клиентского сертификата

```bash
cd services/mysql/pki

# Создать директорию для клиентских сертификатов
mkdir -p client

# Генерация ключа и сертификата
openssl genrsa -out client/app_user.key 2048
openssl req -new -key client/app_user.key -out client/app_user.csr \
  -subj "/CN=app_user/O=CT-System/C=RU"
openssl x509 -req -in client/app_user.csr \
  -CA ca/ca.crt -CAkey ca/ca.key -CAcreateserial \
  -out client/app_user.crt -days 365

chmod 644 client/app_user.key client/app_user.crt
```

### 2. Создание пользователя в MySQL

```bash
# Подключение к MySQL
docker exec -it mysql mysql -u root -proot
```

```sql
-- Создать пользователя с обязательным SSL
CREATE USER 'app_user'@'%' 
  IDENTIFIED BY 'secure_password' 
  REQUIRE SSL;

GRANT ALL PRIVILEGES ON ct_system.* TO 'app_user'@'%';
FLUSH PRIVILEGES;

-- Проверить
SELECT User, Host, ssl_type FROM mysql.user WHERE User = 'app_user';
```

### 3. Подключение с сертификатом

```bash
mysql -h 127.0.0.1 -u app_user -psecure_password \
  --ssl-ca=services/mysql/pki/ca/ca.crt \
  --ssl-cert=services/mysql/pki/client/app_user.crt \
  --ssl-key=services/mysql/pki/client/app_user.key
```

## Варианты требований SSL

| Тип | SQL | Описание |
|-----|-----|----------|
| **REQUIRE SSL** | `CREATE USER 'u'@'%' REQUIRE SSL;` | Любое SSL соединение |
| **REQUIRE X509** | `CREATE USER 'u'@'%' REQUIRE X509;` | Валидный клиентский сертификат |
| **REQUIRE ISSUER** | `REQUIRE ISSUER '/CN=CA'` | От конкретного CA |
| **REQUIRE SUBJECT** | `REQUIRE SUBJECT '/CN=user'` | Конкретный сертификат |

## Автоматизация: Скрипт создания пользователя

**scripts/create-mysql-user.sh:**
```bash
#!/bin/bash
set -e

USERNAME=$1
PASSWORD=$2

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

cd services/mysql/pki

# Генерация сертификата
openssl genrsa -out client/${USERNAME}.key 2048
openssl req -new -key client/${USERNAME}.key -out client/${USERNAME}.csr \
  -subj "/CN=${USERNAME}/O=CT-System/C=RU"
openssl x509 -req -in client/${USERNAME}.csr \
  -CA ca/ca.crt -CAkey ca/ca.key -CAcreateserial \
  -out client/${USERNAME}.crt -days 365
chmod 644 client/${USERNAME}.key client/${USERNAME}.crt

# Создание пользователя
docker exec -i mysql mysql -u root -proot << EOF
CREATE USER '${USERNAME}'@'%' IDENTIFIED BY '${PASSWORD}' REQUIRE SSL;
GRANT ALL PRIVILEGES ON ct_system.* TO '${USERNAME}'@'%';
FLUSH PRIVILEGES;
EOF

echo "✓ User created!"
echo "Connect: mysql -h 127.0.0.1 -u ${USERNAME} -p${PASSWORD} \\"
echo "  --ssl-ca=services/mysql/pki/ca/ca.crt \\"
echo "  --ssl-cert=services/mysql/pki/client/${USERNAME}.crt \\"
echo "  --ssl-key=services/mysql/pki/client/${USERNAME}.key"
```

**Использование:**
```bash
chmod +x scripts/create-mysql-user.sh
./scripts/create-mysql-user.sh cts_app my_secure_pass
```

## Подключение из Go приложения

```go
import (
    "crypto/tls"
    "crypto/x509"
    "database/sql"
    "github.com/go-sql-driver/mysql"
)

// Загрузка CA
rootCertPool := x509.NewCertPool()
pem, _ := os.ReadFile("services/mysql/pki/ca/ca.crt")
rootCertPool.AppendCertsFromPEM(pem)

// Загрузка клиентского сертификата
clientCert, _ := tls.LoadX509KeyPair(
    "services/mysql/pki/client/app_user.crt",
    "services/mysql/pki/client/app_user.key",
)

// Регистрация TLS конфига
mysql.RegisterTLSConfig("custom", &tls.Config{
    RootCAs:      rootCertPool,
    Certificates: []tls.Certificate{clientCert},
})

// DSN с TLS
dsn := "app_user:password@tcp(localhost:3306)/ct_system?tls=custom"
db, _ := sql.Open("mysql", dsn)
```

## Проверка SSL

```sql
-- Текущее соединение
SHOW STATUS LIKE 'Ssl_cipher';

-- Все SSL параметры
SHOW STATUS LIKE 'Ssl%';

-- Требования для пользователей
SELECT User, Host, ssl_type FROM mysql.user;
```

## Troubleshooting

### Unable to get private key
```bash
chmod 644 services/mysql/pki/server/mysql.server.key
docker compose restart mysql
```

### Access denied for user with SSL
Убедитесь что используете SSL флаги при подключении:
```bash
mysql -h 127.0.0.1 -u user -p \
  --ssl-ca=services/mysql/pki/ca/ca.crt \
  --ssl-cert=services/mysql/pki/client/user.crt \
  --ssl-key=services/mysql/pki/client/user.key
```

## Production: Обязательный SSL для всех

В `my.cnf` раскомментировать:
```ini
require_secure_transport = on
```

После этого root подключается только:
- Через unix socket: `docker exec -it mysql mysql -u root -p`
- Через TCP с сертификатом

---

**Дата:** 31 января 2026
