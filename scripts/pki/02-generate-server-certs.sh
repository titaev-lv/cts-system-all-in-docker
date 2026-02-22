#!/bin/bash
#
# Generate Server Certificates for CT-System Services
#
# This script generates server certificates for all services that accept
# incoming connections: MySQL, ClickHouse, HSM Service, CTS-Core, and Web UI.
#
# Usage: ./02-generate-server-certs.sh [--force]
#        --force: Regenerate certificates even if they already exist

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
print_info "CT-System Server Certificates Generation"
print_info "========================================="
echo ""

# Check prerequisites
check_prerequisites || exit 1

# Validate CA exists
validate_ca_exists || exit 1

# Server certificates configuration
# Format: "service_name|CN|SAN_DNS|SAN_IP|output_dir"
declare -a SERVERS=(
    "mysql|mysql|mysql,ct-system-mysql,localhost|127.0.0.1|mysql/server"
    "clickhouse|clickhouse|clickhouse,ct-system-clickhouse,localhost|127.0.0.1|clickhouse/server"
    "hsm-service|hsm-service|hsm,hsm-service,ct-system-hsm,localhost|127.0.0.1|hsm-service/server"
    "cts-core|cts-core|cts-core,ct-system-cts-core,localhost|127.0.0.1|cts-core/server"
    "web-ui|web-ui|web-ui,ct-system-web-ui,localhost|127.0.0.1|web-ui/server"
)

# Function to generate server certificate
generate_server_cert() {
    local service_name="$1"
    local cn="$2"
    local san_dns="$3"
    local san_ip="$4"
    local output_dir="$5"
    
    local full_output_dir="$PKI_ROOT/$output_dir"
    local key_file="$full_output_dir/${service_name}.key"
    local csr_file="$full_output_dir/${service_name}.csr"
    local cert_file="$full_output_dir/${service_name}.crt"
    local fullchain_file="$full_output_dir/${service_name}.fullchain.crt"
    local ext_file="$full_output_dir/${service_name}.ext"
    
    # Check if certificate already exists
    if [ -f "$cert_file" ] && [ $FORCE -eq 0 ]; then
        print_warning "Certificate already exists: $cert_file"
        print_info "Use --force to regenerate"
        return 0
    fi
    
    echo ""
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Generating server certificate for: $service_name"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Ensure output directory exists
    ensure_dir "$full_output_dir"
    
    # Build subject
    local subject="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=Services/CN=${cn}"
    
    print_info "Common Name: $cn"
    print_info "SAN DNS: $san_dns"
    print_info "SAN IP: $san_ip"
    print_info "Subject: $subject"
    echo ""
    
    # Generate private key
    generate_private_key "$key_file" 4096
    
    # Create CSR
    create_csr "$key_file" "$csr_file" "$subject"
    
    # Create SAN extension file
    create_server_extensions "$ext_file" "$san_dns" "$san_ip"
    
    # Sign certificate
    sign_certificate "$csr_file" "$cert_file" "$ext_file" "$CERT_VALIDITY_DAYS"
    
    # Verify certificate
    verify_certificate "$cert_file"

    # Build full chain certificate for TLS servers (leaf + intermediate)
    cat "$cert_file" "$CA_DIR/intermediate-ca.crt" > "$fullchain_file"
    chmod 644 "$fullchain_file"
    
    # Show certificate info
    show_certificate_info "$cert_file"
    
    # Cleanup temporary files
    rm -f "$csr_file"
    
    print_success "Server certificate for $service_name completed!"
    print_info "Certificate: $cert_file"
    print_info "Full chain:  $fullchain_file"
    print_info "Private key: $key_file"
    echo ""
}

# Generate all server certificates
print_info "Generating ${#SERVERS[@]} server certificates..."
echo ""

for server_config in "${SERVERS[@]}"; do
    IFS='|' read -r service_name cn san_dns san_ip output_dir <<< "$server_config"
    generate_server_cert "$service_name" "$cn" "$san_dns" "$san_ip" "$output_dir"
done

echo ""
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "All server certificates generated successfully!"
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Generated certificates:"
echo "  1. MySQL:       $PKI_ROOT/mysql/server/mysql.{key,crt}"
echo "  2. ClickHouse:  $PKI_ROOT/clickhouse/server/clickhouse.{key,crt}"
echo "  3. HSM Service: $PKI_ROOT/hsm-service/server/hsm-service.{key,crt}"
echo "  4. CTS-Core:    $PKI_ROOT/cts-core/server/cts-core.{key,crt}"
echo "  5. Web UI:      $PKI_ROOT/web-ui/server/web-ui.{key,crt}"
echo "     Fullchain:   <service>.fullchain.crt (leaf + intermediate)"
echo ""

print_info "Next steps:"
print_info "  Run scripts/pki/03-generate-client-certs.sh to generate client certificates"
echo ""

print_info "Testing server certificates:"
echo "  # Verify certificate with CA"
echo "  openssl verify -CAfile $CA_DIR/ca.crt $PKI_ROOT/mysql/server/mysql.crt"
echo ""
echo "  # Check SAN entries"
echo "  openssl x509 -in $PKI_ROOT/mysql/server/mysql.crt -noout -text | grep -A1 'Subject Alternative Name'"
echo ""
