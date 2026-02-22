#!/bin/bash
# Remove CT-System dev Root CA from Linux trust stores
# Usage: ./scripts/pki/uninstall-dev-ca-linux.sh

set -euo pipefail

CA_NICKNAME="CT-System-Dev-Root-CA"
SYSTEM_CA_FILE="/usr/local/share/ca-certificates/ct-system-dev-root-ca.crt"

remove_from_nss_db() {
    local db_path="$1"

    if [ ! -d "$db_path" ]; then
        return 0
    fi

    if [ ! -f "$db_path/cert9.db" ]; then
        return 0
    fi

    certutil -d sql:"$db_path" -D -n "$CA_NICKNAME" >/dev/null 2>&1 || true
    return 0
}

if ! command -v update-ca-certificates >/dev/null 2>&1; then
    echo "✗ update-ca-certificates not found (unsupported distro/tooling)"
    exit 1
fi

echo "→ Removing CT-System Root CA from system trust store..."
if [ -f "$SYSTEM_CA_FILE" ]; then
    sudo rm -f "$SYSTEM_CA_FILE"
else
    echo "ℹ System CA file not found: $SYSTEM_CA_FILE"
fi
sudo update-ca-certificates

echo "✓ System trust store updated"

if command -v certutil >/dev/null 2>&1; then
    NSS_DB="$HOME/.pki/nssdb"
    echo "→ Removing CA from NSS database ($NSS_DB)..."
    remove_from_nss_db "$NSS_DB"
    echo "✓ NSS cleanup complete"

    FIREFOX_BASES=(
        "$HOME/.mozilla/firefox"
        "$HOME/snap/firefox/common/.mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    )

    for firefox_base in "${FIREFOX_BASES[@]}"; do
        if [ -d "$firefox_base" ]; then
            echo "→ Removing CA from Firefox profiles ($firefox_base)..."
            while IFS= read -r profile_db; do
                remove_from_nss_db "$profile_db"
                echo "✓ Firefox cleanup complete: $profile_db"
            done < <(find "$firefox_base" -maxdepth 1 -mindepth 1 -type d)
        fi
    done
else
    echo "⚠ certutil not found. Install libnss3-tools to clean browser NSS trust stores."
fi

echo "✓ Done. Fully restart browser to apply trust-store changes"
