#!/bin/bash
# Install CT-System dev Root CA into Linux trust stores
# Usage: ./scripts/pki/install-dev-ca-linux.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CA_ROOT_CERT="$PROJECT_ROOT/volumes/pki/ca/root-ca.crt"
SYSTEM_CA_FILE="/usr/local/share/ca-certificates/ct-system-dev-root-ca.crt"
CA_NICKNAME="CT-System-Dev-Root-CA"

import_into_nss_db() {
    local db_path="$1"

    if [ ! -d "$db_path" ]; then
        return 0
    fi

    if [ ! -f "$db_path/cert9.db" ]; then
        certutil -d sql:"$db_path" -N --empty-password >/dev/null 2>&1 || true
    fi

    certutil -d sql:"$db_path" -D -n "$CA_NICKNAME" >/dev/null 2>&1 || true
    certutil -d sql:"$db_path" -A -t "C,," -n "$CA_NICKNAME" -i "$CA_ROOT_CERT" >/dev/null 2>&1 || return 1
    return 0
}

if [ ! -f "$CA_ROOT_CERT" ]; then
    echo "✗ Root CA certificate not found: $CA_ROOT_CERT"
    echo "  Run ./scripts/pki/01-generate-ca.sh first"
    exit 1
fi

if ! command -v update-ca-certificates >/dev/null 2>&1; then
    echo "✗ update-ca-certificates not found (unsupported distro/tooling)"
    exit 1
fi

echo "→ Installing CT-System Root CA into system trust store..."
sudo cp "$CA_ROOT_CERT" "$SYSTEM_CA_FILE"
sudo chmod 644 "$SYSTEM_CA_FILE"
sudo update-ca-certificates

echo "✓ System trust store updated"

if command -v certutil >/dev/null 2>&1; then
    NSS_DB="$HOME/.pki/nssdb"
    mkdir -p "$NSS_DB"
    echo "→ Installing CA into NSS database ($NSS_DB)..."
    if import_into_nss_db "$NSS_DB"; then
        echo "✓ NSS trust updated: $NSS_DB"
    else
        echo "⚠ Could not update NSS DB: $NSS_DB (maybe password-protected)"
    fi

    FIREFOX_BASES=(
        "$HOME/.mozilla/firefox"
        "$HOME/snap/firefox/common/.mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    )

    for firefox_base in "${FIREFOX_BASES[@]}"; do
        if [ -d "$firefox_base" ]; then
            echo "→ Installing CA into Firefox profiles ($firefox_base)..."
            while IFS= read -r profile_db; do
                if import_into_nss_db "$profile_db"; then
                    echo "✓ Firefox trust updated: $profile_db"
                else
                    echo "⚠ Could not update Firefox profile: $profile_db (maybe password-protected)"
                fi
            done < <(find "$firefox_base" -maxdepth 1 -mindepth 1 -type d)
        fi
    done
else
    echo "⚠ certutil not found. Install libnss3-tools to update browser NSS trust stores."
fi

echo "✓ Done. Fully restart browser and reopen https://localhost"
