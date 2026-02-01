#!/bin/bash
#
# Clean PKI Infrastructure
#
# This script removes all generated certificates and keys.
# Use with caution! This will require regenerating all certificates.
#
# Usage: ./clean-pki.sh [--yes]
#        --yes: Skip confirmation prompt

set -e

# Load helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Parse arguments
SKIP_CONFIRM=0
if [ "$1" = "--yes" ]; then
    SKIP_CONFIRM=1
fi

echo ""
print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_warning "PKI Infrastructure Cleanup"
print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check what will be deleted
print_info "This will delete:"
echo "  • Root CA certificate and key"
echo "  • All server certificates (mysql, clickhouse, hsm-service, cts-core)"
echo "  • All client certificates (16 certificates)"
echo ""
print_warning "⚠️  WARNING: All certificates will be invalidated!"
print_warning "⚠️  WARNING: Services using these certificates will fail to connect!"
echo ""

# List what exists
if [ -d "$PKI_ROOT" ]; then
    print_info "Current PKI structure:"
    echo ""
    
    # Count files
    local total_keys=$(find "$PKI_ROOT" -name "*.key" 2>/dev/null | wc -l)
    local total_certs=$(find "$PKI_ROOT" -name "*.crt" 2>/dev/null | wc -l)
    
    if [ $total_keys -gt 0 ] || [ $total_certs -gt 0 ]; then
        echo "  • Private keys (.key): $total_keys"
        echo "  • Certificates (.crt): $total_certs"
        echo ""
    else
        print_info "No certificates found (PKI is already clean)"
        exit 0
    fi
else
    print_info "PKI directory does not exist"
    exit 0
fi

# Confirm deletion
if [ $SKIP_CONFIRM -eq 0 ]; then
    if ! confirm "Are you sure you want to delete all certificates?" "n"; then
        print_info "Aborted."
        exit 0
    fi
fi

echo ""
print_step "Cleaning PKI infrastructure..."

# Delete certificate files (keep directory structure)
find "$PKI_ROOT" -type f \( -name "*.key" -o -name "*.crt" -o -name "*.csr" -o -name "*.ext" -o -name "*.srl" \) -delete 2>/dev/null || true

print_success "All certificates and keys have been deleted"
echo ""

print_info "Directory structure preserved:"
find "$PKI_ROOT" -type d | sort

echo ""
print_success "PKI cleanup completed!"
echo ""
print_info "To regenerate certificates:"
echo "  1. ./scripts/pki/01-generate-ca.sh"
echo "  2. ./scripts/pki/02-generate-server-certs.sh"
echo "  3. ./scripts/pki/03-generate-client-certs.sh"
echo ""
print_info "Or run: ./init-system.sh (if it exists)"
echo ""
