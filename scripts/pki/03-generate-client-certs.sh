#!/bin/bash
#
# Generate Client Certificates for CT-System Services
#
# This script generates client certificates for all services that connect
# to servers using mTLS. Each certificate has appropriate OU for access control.
#
# Usage: ./03-generate-client-certs.sh [--force]
#        --force: Regenerate certificates even if they already exist

set -euo pipefail

# Load helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Parse arguments
FORCE=0
if [ "${1:-}" = "--force" ]; then
    FORCE=1
fi

echo ""
print_info "CT-System Client Certificates Generation"
print_info "========================================="
echo ""

# Check prerequisites
check_prerequisites || exit 1

# Validate CA exists
validate_ca_exists || exit 1

# Client certificates configuration
# Format: "client_name|CN|OU|output_dir|description"
CLIENTS=(
    # MySQL clients
    "web-ui-mysql|web-ui-mysql-client|Database|mysql/clients/web-ui|Web UI to MySQL"
    "cts-core-mysql|cts-core-mysql-client|Database|mysql/clients/cts-core|CTS-Core to MySQL"
    
    # HSM clients - 2FA context
    "web-ui-hsm-2fa|web-ui-hsm-2fa|2FA|hsm-service/clients/web-ui-2fa|Web UI to HSM (2FA)"
    "cts-core-hsm-2fa|cts-core-hsm-2fa|2FA|hsm-service/clients/cts-core-2fa|CTS-Core to HSM (2FA)"
    
    # HSM clients - Trader context
    "cts-core-hsm-trader|cts-core-hsm-trader|Trader|hsm-service/clients/cts-core-trader|CTS-Core to HSM (Trader)"
    "trader-1-hsm|trader-1-hsm-client|Trader|hsm-service/clients/trader-1|Trader-1 to HSM"
    "trader-2-hsm|trader-2-hsm-client|Trader|hsm-service/clients/trader-2|Trader-2 to HSM"
    "trader-3-hsm|trader-3-hsm-client|Trader|hsm-service/clients/trader-3|Trader-3 to HSM"
    
    # ClickHouse clients
    "web-ui-clickhouse|web-ui-clickhouse-client|Database|clickhouse/clients/web-ui|Web UI to ClickHouse"
    "trader-1-clickhouse|trader-1-clickhouse-client|Database|clickhouse/clients/trader-1|Trader-1 to ClickHouse"
    "trader-2-clickhouse|trader-2-clickhouse-client|Database|clickhouse/clients/trader-2|Trader-2 to ClickHouse"
    "trader-3-clickhouse|trader-3-clickhouse-client|Database|clickhouse/clients/trader-3|Trader-3 to ClickHouse"
    
    # CTS-Core clients
    "web-ui-cts|web-ui-cts-client|Admin|cts-core/clients/web-ui|Web UI to CTS-Core"
    "trader-1-cts|trader-1-cts-client|Trader|cts-core/clients/trader-1|Trader-1 to CTS-Core"
    "trader-2-cts|trader-2-cts-client|Trader|cts-core/clients/trader-2|Trader-2 to CTS-Core"
    "trader-3-cts|trader-3-cts-client|Trader|cts-core/clients/trader-3|Trader-3 to CTS-Core"
)

# Function to generate client certificate
generate_client_cert() {
    local client_name="$1"
    local cn="$2"
    local ou="$3"
    local output_dir="$4"
    local description="$5"
    
    local full_output_dir="$PKI_ROOT/$output_dir"
    local key_file="$full_output_dir/${client_name}.key"
    local csr_file="$full_output_dir/${client_name}.csr"
    local cert_file="$full_output_dir/${client_name}.crt"
    local ext_file="$full_output_dir/${client_name}.ext"
    
    # Check if certificate already exists
    if [ -f "$cert_file" ] && [ $FORCE -eq 0 ]; then
        print_warning "Certificate already exists: $cert_file"
        return 0
    fi
    
    echo ""
    print_step "Generating client certificate: $description"
    
    # Ensure output directory exists
    ensure_dir "$full_output_dir"
    
    # Build subject
    local subject="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ou}/CN=${cn}"
    
    print_info "Common Name: $cn"
    print_info "OU: $ou (for access control)"
    
    # Generate private key
    generate_private_key "$key_file" 4096
    
    # Create CSR
    create_csr "$key_file" "$csr_file" "$subject"
    
    # Create client extension file
    create_client_extensions "$ext_file"
    
    # Sign certificate
    sign_certificate "$csr_file" "$cert_file" "$ext_file" "$CERT_VALIDITY_DAYS"
    
    # Verify certificate
    verify_certificate "$cert_file" || {
        print_error "Certificate verification failed for $client_name"
        return 1
    }
    
    # Cleanup temporary files
    rm -f "$csr_file" "$ext_file"
    
    print_success "Client certificate for $client_name completed!"
}

# Count certificates by category
print_info "Generating ${#CLIENTS[@]} client certificates..."
echo ""

# Group certificates by category for better output
print_info "Categories:"
print_info "  • MySQL clients (Database OU): 2"
print_info "  • HSM clients (2FA OU): 2"
print_info "  • HSM clients (Trader OU): 4"
print_info "  • ClickHouse clients (Database OU): 4"
print_info "  • CTS-Core clients (Admin/Trader OU): 4"
echo ""

# Generate all client certificates
cert_count=0
for client_config in "${CLIENTS[@]}"; do
    IFS='|' read -r client_name cn ou output_dir description <<< "$client_config"
    cert_count=$((cert_count + 1))
    
    echo ""
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "[$cert_count/${#CLIENTS[@]}] $description"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    generate_client_cert "$client_name" "$cn" "$ou" "$output_dir" "$description"
done

echo ""
echo ""
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "All client certificates generated successfully!"
print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Generated certificates by service:"
echo ""
echo "MySQL (2 clients):"
echo "  • $PKI_ROOT/mysql/clients/web-ui/web-ui-mysql.{key,crt}"
echo "  • $PKI_ROOT/mysql/clients/cts-core/cts-core-mysql.{key,crt}"
echo ""
echo "HSM Service (6 clients):"
echo "  • $PKI_ROOT/hsm-service/clients/web-ui-2fa/web-ui-hsm-2fa.{key,crt}"
echo "  • $PKI_ROOT/hsm-service/clients/cts-core-2fa/cts-core-hsm-2fa.{key,crt}"
echo "  • $PKI_ROOT/hsm-service/clients/cts-core-trader/cts-core-hsm-trader.{key,crt}"
echo "  • $PKI_ROOT/hsm-service/clients/trader-{1,2,3}/trader-*-hsm.{key,crt}"
echo ""
echo "ClickHouse (4 clients):"
echo "  • $PKI_ROOT/clickhouse/clients/web-ui/web-ui-clickhouse.{key,crt}"
echo "  • $PKI_ROOT/clickhouse/clients/trader-{1,2,3}/trader-*-clickhouse.{key,crt}"
echo ""
echo "CTS-Core (4 clients):"
echo "  • $PKI_ROOT/cts-core/clients/web-ui/web-ui-cts.{key,crt}"
echo "  • $PKI_ROOT/cts-core/clients/trader-{1,2,3}/trader-*-cts.{key,crt}"
echo ""

print_info "Summary:"
echo "  • Total certificates: ${#CLIENTS[@]} client + 4 server + 1 CA = $((${#CLIENTS[@]} + 5))"
echo "  • All certificates valid for: $CERT_VALIDITY_DAYS days (~2.3 years)"
echo "  • Access control by OU: Database, 2FA, Trader, Admin"
echo ""

print_info "Testing client certificates:"
echo "  # Verify certificate with CA"
echo "  openssl verify -CAfile $CA_DIR/ca.crt $PKI_ROOT/mysql/clients/web-ui/web-ui-mysql.crt"
echo ""
echo "  # Check certificate details"
echo "  openssl x509 -in $PKI_ROOT/hsm-service/clients/trader-1/trader-1-hsm.crt -noout -subject -issuer"
echo ""
echo "  # Test mTLS connection (example for MySQL)"
echo "  mysql --ssl-ca=$CA_DIR/ca.crt \\"
echo "        --ssl-cert=$PKI_ROOT/mysql/clients/web-ui/web-ui-mysql.crt \\"
echo "        --ssl-key=$PKI_ROOT/mysql/clients/web-ui/web-ui-mysql.key \\"
echo "        -h mysql -u user -p"
echo ""

print_success "PKI infrastructure is ready!"
print_info "Next steps:"
print_info "  1. Update docker-compose.yml to mount these certificates"
print_info "  2. Configure services to use mTLS"
print_info "  3. Run ./init-system.sh to deploy the system"
echo ""
