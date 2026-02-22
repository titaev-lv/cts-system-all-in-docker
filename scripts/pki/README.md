# PKI Scripts

Scripts for generating and managing PKI infrastructure for CT-System mTLS communication.

## Overview

These scripts automate the generation of:
- **1 Root CA** (self-signed for dev)
- **5 Server certificates** (MySQL, ClickHouse, HSM Service, CTS-Core, Web UI)
- **16 Client certificates** (with appropriate OU for access control)

## Usage

### Full PKI Generation

Run all scripts in order:

```bash
# 1. Generate Root CA
./scripts/pki/01-generate-ca.sh

# 2. Generate server certificates
./scripts/pki/02-generate-server-certs.sh

# 3. Generate client certificates
./scripts/pki/03-generate-client-certs.sh
```

Or use the init-system script:
```bash
./init-system.sh
```

### Regenerate PKI

To regenerate all certificates:

```bash
# Clean existing PKI
./scripts/pki/clean-pki.sh --yes

# Regenerate
./scripts/pki/01-generate-ca.sh
./scripts/pki/02-generate-server-certs.sh
./scripts/pki/03-generate-client-certs.sh
```

Or force regenerate individual components:

```bash
./scripts/pki/01-generate-ca.sh --force
./scripts/pki/02-generate-server-certs.sh --force
./scripts/pki/03-generate-client-certs.sh --force
```

## Scripts

### `helpers.sh`

Common functions used by all PKI scripts:
- Color output functions
- Certificate generation helpers
- Validation functions
- SAN extension builders

**Not meant to be run directly** - sourced by other scripts.

### `01-generate-ca.sh`

Generates self-signed Root CA certificate.

**Output:**
- `volumes/pki/ca/ca.key` - CA private key (4096-bit RSA)
- `volumes/pki/ca/ca.crt` - CA certificate (valid 10 years)
- `volumes/pki/ca/ca.srl` - Serial number file

**Options:**
- `--force` - Regenerate even if CA exists (invalidates all certificates!)

**Example:**
```bash
./scripts/pki/01-generate-ca.sh
```

### `02-generate-server-certs.sh`

Generates server certificates for all services that accept incoming connections.

**Generates certificates for:**
1. MySQL (`mysql.{key,crt}`)
2. ClickHouse (`clickhouse.{key,crt}`)
3. HSM Service (`hsm-service.{key,crt}`)
4. CTS-Core (`cts-core.{key,crt}`)
5. Web UI (`web-ui.{key,crt}`)

**Features:**
- Subject Alternative Names (SAN) for Docker network DNS
- Valid for 825 days (~2.3 years)
- Extensions: serverAuth, digitalSignature, keyEncipherment
- Generates `<service>.fullchain.crt` (leaf + intermediate) for HTTPS servers

**Options:**
- `--force` - Regenerate existing certificates

**Example:**
```bash
./scripts/pki/02-generate-server-certs.sh
```

### `install-dev-ca-linux.sh`

Installs CT-System dev Root CA into Linux system trust store to avoid browser SSL warnings for `https://localhost`.

**Requirements:**
- Linux with `update-ca-certificates`
- `sudo` access

**Example:**
```bash
./scripts/pki/install-dev-ca-linux.sh
```

### `uninstall-dev-ca-linux.sh`

Removes CT-System dev Root CA from Linux system trust store and browser NSS/Firefox profiles.

**Requirements:**
- Linux with `update-ca-certificates`
- `sudo` access

**Example:**
```bash
./scripts/pki/uninstall-dev-ca-linux.sh
```

### `03-generate-client-certs.sh`

Generates client certificates for all services that connect to servers using mTLS.

**Generates 16 certificates:**

**MySQL Clients (OU=Database):**
- web-ui → MySQL
- cts-core → MySQL

**HSM Clients (OU=2FA):**
- web-ui → HSM (2FA context)
- cts-core → HSM (2FA context)

**HSM Clients (OU=Trader):**
- cts-core → HSM (Trader context)
- trader-{1,2,3} → HSM

**ClickHouse Clients (OU=Database):**
- web-ui → ClickHouse
- trader-{1,2,3} → ClickHouse

**CTS-Core Clients (OU=Admin/Trader):**
- web-ui → CTS-Core (Admin)
- trader-{1,2,3} → CTS-Core (Trader)

**Features:**
- OU-based access control (Database, 2FA, Trader, Admin)
- Valid for 825 days
- Extensions: clientAuth, digitalSignature

**Options:**
- `--force` - Regenerate existing certificates

**Example:**
```bash
./scripts/pki/03-generate-client-certs.sh
```

### `clean-pki.sh`

Removes all generated certificates and keys while preserving directory structure.

**Warning:** This will invalidate all existing certificates!

**Options:**
- `--yes` - Skip confirmation prompt

**Example:**
```bash
# With confirmation
./scripts/pki/clean-pki.sh

# Without confirmation
./scripts/pki/clean-pki.sh --yes
```

## Certificate Specifications

### Root CA
```
Subject: /C=RU/ST=Moscow/L=Moscow/O=CT-System-Dev/CN=CT-System-Dev-CA
Validity: 3650 days (10 years)
Key: RSA 4096
```

### Server Certificates
```
Subject: /C=RU/ST=Moscow/L=Moscow/O=CT-System-Dev/OU=Services/CN=<service-name>
SAN: DNS:<service-name>,DNS:<container-name>,DNS:localhost,IP:127.0.0.1
Validity: 825 days
Key: RSA 4096
Extensions: serverAuth
```

### Client Certificates
```
Subject: /C=RU/ST=Moscow/L=Moscow/O=CT-System-Dev/OU=<context>/CN=<client-name>
OU: Database | 2FA | Trader | Admin
Validity: 825 days
Key: RSA 4096
Extensions: clientAuth
```

## Verification

### Verify Certificate with CA
```bash
openssl verify -CAfile volumes/pki/ca/ca.crt volumes/pki/mysql/server/mysql.crt
```

### Check SAN Entries
```bash
openssl x509 -in volumes/pki/mysql/server/mysql.crt -noout -text | grep -A1 "Subject Alternative Name"
```

### Check Certificate OU
```bash
openssl x509 -in volumes/pki/hsm-service/clients/trader-1/trader-1-hsm.crt -noout -subject
```

### Test mTLS Connection (MySQL example)
```bash
mysql --ssl-ca=volumes/pki/ca/ca.crt \
      --ssl-cert=volumes/pki/mysql/clients/web-ui/web-ui-mysql.crt \
      --ssl-key=volumes/pki/mysql/clients/web-ui/web-ui-mysql.key \
      -h mysql -u user -p
```

## Directory Structure

```
volumes/pki/
├── ca/                    # Root CA
│   ├── ca.key            # CA private key
│   ├── ca.crt            # CA certificate
│   └── ca.srl            # Serial number
├── mysql/
│   ├── server/           # MySQL server cert
│   └── clients/          # MySQL client certs
├── clickhouse/
│   ├── server/
│   └── clients/
├── hsm-service/
│   ├── server/
│   └── clients/          # With OU=2FA or OU=Trader
├── cts-core/
│   ├── server/
│   └── clients/
└── web-ui/
    └── server/
```

## Security Notes

### Development Environment
- ✅ Self-signed CA is acceptable
- ✅ 10-year CA lifetime is acceptable
- ✅ Certificates in git (generated, not sensitive)
- ⚠️ Private keys excluded via .gitignore

### Production Environment
- ❌ Do NOT use self-signed CA
- ❌ Do NOT use these scripts directly
- ✅ Use corporate CA or commercial CA
- ✅ Implement certificate rotation
- ✅ Use shorter certificate lifetimes
- ✅ Consider Vault or Step-CA for automation

## Troubleshooting

### "CA certificate or key not found"
```bash
# Generate CA first
./scripts/pki/01-generate-ca.sh
```

### "Certificate already exists"
```bash
# Use --force to regenerate
./scripts/pki/02-generate-server-certs.sh --force
```

### "openssl: command not found"
```bash
# Install OpenSSL
# Ubuntu/Debian:
sudo apt-get install openssl

# macOS:
brew install openssl
```

### Certificate verification fails
```bash
# Regenerate all certificates
./scripts/pki/clean-pki.sh --yes
./scripts/pki/01-generate-ca.sh
./scripts/pki/02-generate-server-certs.sh
./scripts/pki/03-generate-client-certs.sh
```

## See Also

- [PKI Infrastructure Plan](../../docs/PKI_INFRASTRUCTURE_PLAN.md)
- [MySQL SSL Setup](../../docs/MYSQL_SSL_SETUP.md)
- [HSM Service Architecture](../../services/hsm-service/ARCHITECTURE.md)
- [volumes/pki/README.md](../../volumes/pki/README.md)
