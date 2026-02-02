#!/bin/bash
#
# Generate Root CA + Intermediate CA for CT-System Dev Environment
#
# This script creates a hierarchical CA structure:
#  1. Root CA (self-signed) - kept secure, rarely used
#  2. Intermediate CA (signed by Root) - used to sign all server and client certs
#
# This eliminates MySQL warnings about self-signed CA.
#
# Usage: ./01-generate-ca.sh [--force]
#        --force: Regenerate CA chain even if it already exists

set -e

# Load helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Parse arguments
FORCE=0
if [ "$1" = "--force" ]; then
    FORCE=1
fi

echo ""
print_info "CT-System CA Hierarchy Generation (Root + Intermediate)"
print_info "========================================================"
echo ""

# Check prerequisites
check_prerequisites || exit 1

# Ensure CA directory exists
ensure_dir "$CA_DIR"

# Check if CA already exists
if [ -f "$CA_DIR/ca.crt" ] && [ -f "$CA_DIR/root-ca.crt" ]; then
    if [ $FORCE -eq 0 ]; then
        print_warning "CA chain already exists"
        echo ""
        print_info "To regenerate the CA chain, use: $0 --force"
        print_warning "⚠️  WARNING: Regenerating CA will invalidate ALL existing certificates!"
        exit 0
    else
        print_warning "Force mode: Regenerating CA chain"
        if ! confirm "This will INVALIDATE ALL existing certificates. Continue?" "n"; then
            print_info "Aborted."
            exit 0
        fi
    fi
fi

# ============================================================================
# STAGE 1: Generate Root CA (Self-signed)
# ============================================================================
echo ""
print_step "STAGE 1: Generating Root CA (Self-signed)"
print_info "Root CA is the trust anchor. It's self-signed and kept secure."
echo ""

ROOT_CN="CT-System-Dev-Root-CA"
ROOT_KEY="$CA_DIR/root-ca.key"
ROOT_CERT="$CA_DIR/root-ca.crt"

# Generate Root CA private key
print_step "Generating Root CA private key (RSA 4096)..."
openssl genrsa -out "$ROOT_KEY" 4096 2>/dev/null
chmod 600 "$ROOT_KEY"
print_success "Root CA private key created"

# Generate self-signed Root CA certificate
print_step "Generating self-signed Root CA certificate..."
openssl req -new -x509 \
    -key "$ROOT_KEY" \
    -out "$ROOT_CERT" \
    -days "$CA_VALIDITY_DAYS" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/CN=${ROOT_CN}" \
    -extensions v3_ca \
    -config <(cat <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[ req_distinguished_name ]

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:1
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
) 2>/dev/null

chmod 644 "$ROOT_CERT"
print_success "Root CA certificate created (self-signed)"

# ============================================================================
# STAGE 2: Generate Intermediate CA (Signed by Root)
# ============================================================================
echo ""
print_step "STAGE 2: Generating Intermediate CA (Signed by Root)"
print_info "Intermediate CA will sign all server and client certificates."
print_info "This breaks the self-signed chain, eliminating MySQL warnings."
echo ""

INT_CN="CT-System-Dev-Intermediate-CA"
INT_KEY="$CA_DIR/intermediate-ca.key"
INT_CSR="$CA_DIR/intermediate-ca.csr"
INT_CERT="$CA_DIR/intermediate-ca.crt"

# Generate Intermediate CA private key
print_step "Generating Intermediate CA private key (RSA 4096)..."
openssl genrsa -out "$INT_KEY" 4096 2>/dev/null
chmod 600 "$INT_KEY"
print_success "Intermediate CA private key created"

# Generate Intermediate CA certificate signing request
print_step "Creating certificate signing request for Intermediate CA..."
openssl req -new \
    -key "$INT_KEY" \
    -out "$INT_CSR" \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/CN=${INT_CN}" \
    -config <(cat <<EOF
[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_intermediate_ca

[ req_distinguished_name ]

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
) 2>/dev/null

print_success "Intermediate CA CSR created"

# Sign Intermediate CA certificate with Root CA
print_step "Signing Intermediate CA with Root CA..."
openssl x509 -req \
    -in "$INT_CSR" \
    -CA "$ROOT_CERT" \
    -CAkey "$ROOT_KEY" \
    -CAcreateserial \
    -out "$INT_CERT" \
    -days "$INT_VALIDITY_DAYS" \
    -extensions v3_intermediate_ca \
    -extfile <(cat <<EOF
[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
) 2>/dev/null

chmod 644 "$INT_CERT"
print_success "Intermediate CA certificate signed by Root CA"

# Verify Intermediate CA was signed correctly
print_step "Verifying Intermediate CA signature..."
if openssl verify -CAfile "$ROOT_CERT" "$INT_CERT" >/dev/null 2>&1; then
    print_success "✓ Intermediate CA signature verified against Root CA"
else
    print_error "Failed to verify Intermediate CA signature"
    exit 1
fi

# ============================================================================
# STAGE 3: Set up CA certificate for use by services
# ============================================================================
echo ""
print_step "STAGE 3: Setting up CA certificate for services"
print_info "Services will use Intermediate CA as their trust anchor."
echo ""

CA_CERT="$CA_DIR/ca.crt"

# Copy Intermediate CA as the main CA certificate for services
cp "$INT_CERT" "$CA_CERT"
print_success "Intermediate CA published as ca.crt for services"

# Create certificate chain file (optional, for client verification)
CHAIN_FILE="$CA_DIR/ca-chain.crt"
cat "$INT_CERT" "$ROOT_CERT" > "$CHAIN_FILE"
chmod 644 "$CHAIN_FILE"
print_success "Full certificate chain created: ca-chain.crt"

# Clean up CSR (no longer needed)
rm -f "$INT_CSR"

# Initialize serial number file for signing operations
echo "01" > "$CA_DIR/ca.srl"

# ============================================================================
# STAGE 4: Verification and Summary
# ============================================================================
echo ""
print_step "STAGE 4: Verification and Summary"
echo ""

print_info "Root CA Certificate:"
openssl x509 -in "$ROOT_CERT" -noout -text | grep -E "Subject:|Issuer:" | head -2 | sed 's/^/  /'
echo ""

print_info "Intermediate CA Certificate:"
openssl x509 -in "$INT_CERT" -noout -text | grep -E "Subject:|Issuer:" | head -2 | sed 's/^/  /'
echo ""

print_info "Certificate Chain:"
echo "  Root CA (self-signed)"
echo "    ↓"
echo "  Intermediate CA (signed by Root)"
echo "    ↓"
echo "  Server & Client Certificates (will be signed by Intermediate)"
echo ""

print_success "CA hierarchy generated successfully!"
echo ""
print_info "Files created:"
echo "  $ROOT_KEY        - Root CA private key (KEEP SECURE!)"
echo "  $ROOT_CERT       - Root CA certificate (self-signed)"
echo "  $INT_KEY         - Intermediate CA private key (KEEP SECURE!)"
echo "  $INT_CERT        - Intermediate CA certificate"
echo "  $CA_CERT         - Published as ca.crt for services"
echo "  $CHAIN_FILE      - Full chain (Root + Intermediate) for verification"
echo ""

print_warning "⚠️  IMPORTANT:"
print_info "  • Root CA and Intermediate CA private keys must be kept secure"
print_info "  • Never commit *.key files to git"
print_info "  • Services will use ca.crt (Intermediate CA) as trust anchor"
print_info "  • MySQL will no longer warn about self-signed CA"
echo ""

print_info "Next steps:"
print_info "  1. Run scripts/pki/02-generate-server-certs.sh to generate server certificates"
print_info "  2. Run scripts/pki/03-generate-client-certs.sh to generate client certificates"
echo ""
