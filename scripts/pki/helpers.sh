#!/bin/bash
#
# PKI Helper Functions
# Common functions used by all PKI generation scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PKI_ROOT="$PROJECT_ROOT/volumes/pki"
CA_DIR="$PKI_ROOT/ca"

# Certificate configuration
COUNTRY="RU"
STATE="Moscow"
CITY="Moscow"
ORGANIZATION="CT-System-Dev"
CA_VALIDITY_DAYS=3650  # 10 years for dev
CERT_VALIDITY_DAYS=825  # Apple/Google max lifetime

# Print functions
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_step() {
    echo -e "${BLUE}→${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing=0
    
    if ! command_exists openssl; then
        print_error "openssl is not installed"
        missing=1
    else
        print_success "openssl found: $(openssl version)"
    fi
    
    if [ $missing -eq 1 ]; then
        print_error "Please install missing dependencies"
        return 1
    fi
    
    return 0
}

# Validate CA exists
validate_ca_exists() {
    if [ ! -f "$CA_DIR/ca.crt" ] || [ ! -f "$CA_DIR/ca.key" ]; then
        print_error "CA certificate or key not found in $CA_DIR"
        print_info "Please run scripts/pki/01-generate-ca.sh first"
        return 1
    fi
    return 0
}

# Create directory if not exists
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_success "Created directory: $dir"
    fi
}

# Generate RSA private key
generate_private_key() {
    local key_file="$1"
    local key_size="${2:-4096}"
    
    print_step "Generating RSA $key_size private key..."
    openssl genrsa -out "$key_file" "$key_size" 2>/dev/null
    chmod 600 "$key_file"
    print_success "Private key saved to $key_file"
}

# Create CSR (Certificate Signing Request)
create_csr() {
    local key_file="$1"
    local csr_file="$2"
    local subject="$3"
    
    print_step "Creating Certificate Signing Request..."
    openssl req -new \
        -key "$key_file" \
        -out "$csr_file" \
        -subj "$subject" 2>/dev/null
    
    print_success "CSR created: $csr_file"
}

# Sign certificate with CA
sign_certificate() {
    local csr_file="$1"
    local cert_file="$2"
    local ext_file="$3"
    local validity_days="$4"
    
    print_step "Signing certificate with CA..."
    openssl x509 -req \
        -in "$csr_file" \
        -CA "$CA_DIR/ca.crt" \
        -CAkey "$CA_DIR/ca.key" \
        -CAcreateserial \
        -out "$cert_file" \
        -days "$validity_days" \
        -extfile "$ext_file" 2>/dev/null
    
    chmod 644 "$cert_file"
    print_success "Certificate signed: $cert_file"
}

# Create SAN extension file for server certificate
create_server_extensions() {
    local ext_file="$1"
    local san_dns="$2"
    local san_ip="$3"
    
    cat > "$ext_file" <<EOF
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
EOF
    
    # Add DNS names
    local dns_index=1
    IFS=',' read -ra DNS_ARRAY <<< "$san_dns"
    for dns in "${DNS_ARRAY[@]}"; do
        echo "DNS.${dns_index} = ${dns}" >> "$ext_file"
        ((dns_index++))
    done
    
    # Add IP addresses
    if [ -n "$san_ip" ]; then
        local ip_index=1
        IFS=',' read -ra IP_ARRAY <<< "$san_ip"
        for ip in "${IP_ARRAY[@]}"; do
            echo "IP.${ip_index} = ${ip}" >> "$ext_file"
            ((ip_index++))
        done
    fi
    
    print_success "SAN extension file created: $ext_file"
}

# Create extension file for client certificate
create_client_extensions() {
    local ext_file="$1"
    
    cat > "$ext_file" <<EOF
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
EOF
    
    print_success "Client extension file created: $ext_file"
}

# Verify certificate
verify_certificate() {
    local cert_file="$1"
    local ca_file="${2:-$CA_DIR/ca.crt}"
    
    print_step "Verifying certificate..."
    if openssl verify -CAfile "$ca_file" "$cert_file" >/dev/null 2>&1; then
        print_success "Certificate verified successfully"
        return 0
    else
        print_error "Certificate verification failed"
        return 1
    fi
}

# Show certificate info
show_certificate_info() {
    local cert_file="$1"
    
    echo ""
    print_info "Certificate Information:"
    echo "----------------------------------------"
    
    # Subject
    echo -n "Subject: "
    openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//'
    
    # Issuer
    echo -n "Issuer: "
    openssl x509 -in "$cert_file" -noout -issuer | sed 's/issuer=//'
    
    # Validity
    echo -n "Valid from: "
    openssl x509 -in "$cert_file" -noout -startdate | sed 's/notBefore=//'
    echo -n "Valid until: "
    openssl x509 -in "$cert_file" -noout -enddate | sed 's/notAfter=//'
    
    # SAN (if exists)
    local san=$(openssl x509 -in "$cert_file" -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^[[:space:]]*//')
    if [ -n "$san" ]; then
        echo "SAN: $san"
    fi
    
    echo "----------------------------------------"
    echo ""
}

# Cleanup temporary files
cleanup_temp_files() {
    local base_path="$1"
    
    if [ -f "${base_path}.csr" ]; then
        rm -f "${base_path}.csr"
        print_info "Cleaned up CSR file"
    fi
    
    if [ -f "${base_path}.ext" ]; then
        rm -f "${base_path}.ext"
        print_info "Cleaned up extension file"
    fi
}

# Ask for confirmation
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi
    
    read -p "$(echo -e "${YELLOW}?${NC} $message $prompt: ")" -n 1 -r
    echo
    
    if [ "$default" = "y" ]; then
        [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
    else
        [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

# Export functions for sourcing
export -f print_info
export -f print_success
export -f print_warning
export -f print_error
export -f print_step
export -f command_exists
export -f check_prerequisites
export -f validate_ca_exists
export -f ensure_dir
export -f generate_private_key
export -f create_csr
export -f sign_certificate
export -f create_server_extensions
export -f create_client_extensions
export -f verify_certificate
export -f show_certificate_info
export -f cleanup_temp_files
export -f confirm
