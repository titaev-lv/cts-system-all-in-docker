#!/bin/bash
#
# Generate Root CA for CT-System Dev Environment
#
# This script creates a self-signed Root CA certificate that will be used
# to sign all server and client certificates in the dev environment.
#
# Usage: ./01-generate-ca.sh [--force]
#        --force: Regenerate CA even if it already exists

set -e

# Load helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Parse arguments
FORCE=0
if [ "$1" = "--force" ]; then
    FORCE=1
fi

# Configuration
CN="CT-System-Dev-CA"
SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/CN=${CN}"

echo ""
print_info "CT-System Root CA Generation"
print_info "=============================="
echo ""

# Check prerequisites
check_prerequisites || exit 1

# Ensure CA directory exists
ensure_dir "$CA_DIR"

# Check if CA already exists
if [ -f "$CA_DIR/ca.crt" ] && [ -f "$CA_DIR/ca.key" ]; then
    if [ $FORCE -eq 0 ]; then
        print_warning "CA certificate already exists: $CA_DIR/ca.crt"
        print_warning "CA private key already exists: $CA_DIR/ca.key"
        echo ""
        print_info "To regenerate the CA, use: $0 --force"
        print_warning "⚠️  WARNING: Regenerating CA will invalidate ALL existing certificates!"
        exit 0
    else
        print_warning "Force mode: Regenerating CA"
        if ! confirm "This will INVALIDATE ALL existing certificates. Continue?" "n"; then
            print_info "Aborted."
            exit 0
        fi
    fi
fi

echo ""
print_step "Generating Root CA for: $CN"
print_info "Subject: $SUBJECT"
print_info "Validity: $CA_VALIDITY_DAYS days (~10 years)"
echo ""

# Generate CA private key
CA_KEY="$CA_DIR/ca.key"
CA_CERT="$CA_DIR/ca.crt"

print_step "Generating CA private key (RSA 4096)..."
openssl genrsa -out "$CA_KEY" 4096 2>/dev/null
chmod 600 "$CA_KEY"
print_success "CA private key saved to $CA_KEY"

# Generate self-signed CA certificate
print_step "Generating self-signed CA certificate..."
openssl req -new -x509 \
    -key "$CA_KEY" \
    -out "$CA_CERT" \
    -days "$CA_VALIDITY_DAYS" \
    -subj "$SUBJECT" \
    -extensions v3_ca \
    -config <(cat <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[ req_distinguished_name ]

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
) 2>/dev/null

chmod 644 "$CA_CERT"
print_success "CA certificate saved to $CA_CERT"

# Initialize serial number file
echo "01" > "$CA_DIR/ca.srl"
print_success "CA serial number initialized"

# Verify CA certificate
print_step "Verifying CA certificate..."
if openssl x509 -in "$CA_CERT" -noout -text >/dev/null 2>&1; then
    print_success "CA certificate is valid"
else
    print_error "CA certificate verification failed"
    exit 1
fi

# Show certificate info
show_certificate_info "$CA_CERT"

# Show fingerprints
echo ""
print_info "CA Certificate Fingerprints:"
echo "----------------------------------------"
echo -n "SHA256: "
openssl x509 -in "$CA_CERT" -noout -fingerprint -sha256 | sed 's/.*=//'
echo -n "SHA1:   "
openssl x509 -in "$CA_CERT" -noout -fingerprint -sha1 | sed 's/.*=//'
echo "----------------------------------------"
echo ""

print_success "Root CA generated successfully!"
echo ""
print_info "Next steps:"
print_info "  1. Run scripts/pki/02-generate-server-certs.sh to generate server certificates"
print_info "  2. Run scripts/pki/03-generate-client-certs.sh to generate client certificates"
echo ""
print_warning "⚠️  IMPORTANT: Keep ca.key secure! Never commit it to git."
print_info "The CA certificate (ca.crt) can be distributed to all services."
echo ""
