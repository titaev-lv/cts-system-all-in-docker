#!/bin/bash
#
# CT-System Initialization Script
#
# This script initializes the entire CT-System development environment:
# - Checks prerequisites
# - Clones service repositories from GitHub
# - Generates PKI infrastructure
# - Initializes configurations
# - Starts Docker Compose services
#
# Usage: ./init-system.sh [--skip-clone] [--skip-pki] [--skip-docker]
#        --skip-clone: Skip cloning GitHub repositories
#        --skip-pki: Skip PKI generation (use existing certificates)
#        --skip-docker: Skip Docker Compose startup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Error handler
trap 'echo ""; print_error "Script failed at line $LINENO"; exit 1' ERR

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
DOCKER_COMPOSE_CMD=""

# Parse arguments
SKIP_CLONE=0
SKIP_PKI=0
SKIP_DOCKER=0

for arg in "$@"; do
    case $arg in
        --skip-clone)
            SKIP_CLONE=1
            shift
            ;;
        --skip-pki)
            SKIP_PKI=1
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=1
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $arg${NC}"
            echo "Usage: $0 [--skip-clone] [--skip-pki] [--skip-docker]"
            exit 1
            ;;
    esac
done

# Print functions
print_header() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}→${NC} $1"
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

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Banner
clear
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                        ║${NC}"
echo -e "${MAGENTA}║          ${GREEN}CT-System Initialization Script${MAGENTA}              ║${NC}"
echo -e "${MAGENTA}║                                                        ║${NC}"
echo -e "${MAGENTA}║  Distributed Crypto Trading System - Dev Environment  ║${NC}"
echo -e "${MAGENTA}║                                                        ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check prerequisites
print_header "Step 1: Checking Prerequisites"

print_step "Checking required software..."

MISSING=0

if ! command_exists docker; then
    print_error "Docker is not installed"
    MISSING=1
else
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_success "Docker found: $DOCKER_VERSION"
fi

if ! command_exists docker-compose && ! docker compose version &>/dev/null; then
    print_error "Docker Compose is not installed"
    MISSING=1
else
    if docker compose version &>/dev/null; then
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "v2+")
        print_success "Docker Compose found: $COMPOSE_VERSION"
        DOCKER_COMPOSE_CMD="docker compose"
    else
        COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        print_success "Docker Compose found: $COMPOSE_VERSION"
        DOCKER_COMPOSE_CMD="docker-compose"
    fi
fi

if ! command_exists git; then
    print_error "Git is not installed"
    MISSING=1
else
    GIT_VERSION=$(git --version | awk '{print $3}')
    print_success "Git found: $GIT_VERSION"
fi

if ! command_exists openssl; then
    print_error "OpenSSL is not installed"
    MISSING=1
else
    OPENSSL_VERSION=$(openssl version | awk '{print $2}')
    print_success "OpenSSL found: $OPENSSL_VERSION"
fi

if [ $MISSING -eq 1 ]; then
    echo ""
    print_error "Missing required dependencies. Please install them and try again."
    exit 1
fi

# Check Docker daemon
print_step "Checking Docker daemon..."
if ! docker info &>/dev/null; then
    print_error "Docker daemon is not running"
    print_info "Please start Docker and try again"
    exit 1
else
    print_success "Docker daemon is running"
fi

echo ""
print_success "All prerequisites satisfied!"

# Step 2: Clone GitHub repositories
if [ $SKIP_CLONE -eq 0 ]; then
    print_header "Step 2: Cloning Service Repositories"
    
    print_info "This step clones service repositories from GitHub"
    echo ""
    
    # Check if .env file exists and load it
    ENV_FILE="$PROJECT_ROOT/.env"
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            print_step "Creating .env from .env.example..."
            cp "$PROJECT_ROOT/.env.example" "$ENV_FILE"
            print_success ".env file created"
            print_warning "Please configure GitHub URLs in .env file"
        else
            print_warning ".env.example not found"
            print_info "Skipping repository cloning"
            ENV_FILE=""
        fi
    fi
    
    # Load environment variables from .env if it exists
    if [ -f "$ENV_FILE" ]; then
        set +a  # Don't export all variables
        source "$ENV_FILE" 2>/dev/null || true
        set -a
    fi
    
    # Define services with their paths and env variable names
    declare -A SERVICES=(
        ["cts-core"]="services/cts-core:CTS_CORE_REPO_URL"
        ["hsm-service"]="services/hsm-service:HSM_SERVICE_REPO_URL"
        ["trader-daemon"]="services/trader-daemon:TRADER_DAEMON_REPO_URL"
        ["web-ui-go"]="services/web-ui-go:WEB_UI_GO_REPO_URL"
    )
    
    CLONED_COUNT=0
    SKIPPED_COUNT=0
    
    # Clone or check services
    for service_name in "${!SERVICES[@]}"; do
        IFS=':' read -r service_path env_var_name <<< "${SERVICES[$service_name]}"
        full_path="$PROJECT_ROOT/$service_path"
        
        # Get repository URL from environment variable
        env_var_name="${env_var_name//[[:space:]]/}"  # Remove whitespace
        repo_url="${!env_var_name:-}"  # Get variable value or empty string
        
        # Check if directory exists and is not empty
        if [ -d "$full_path" ] && [ -n "$(ls -A "$full_path" 2>/dev/null)" ]; then
            # Service directory exists and not empty
            if [ -d "$full_path/.git" ]; then
                print_success "$service_name: Already cloned (git repository)"
            else
                print_warning "$service_name: Directory exists with content (not a git repo)"
            fi
            ((SKIPPED_COUNT++))
        else
            # Service directory doesn't exist or is empty
            if [ -n "$repo_url" ]; then
                # Repository URL is configured
                print_step "Cloning $service_name from $repo_url..."
                
                # Create parent directory if needed
                mkdir -p "$(dirname "$full_path")"
                
                # Remove failed clone attempt if exists
                rm -rf "$full_path" 2>/dev/null || true
                
                # Clone repository
                set +e
                git clone "$repo_url" "$full_path" >/dev/null 2>&1
                CLONE_EXIT=$?
                set -e
                
                if [ $CLONE_EXIT -eq 0 ]; then
                    print_success "$service_name: Cloned successfully"
                    ((CLONED_COUNT++))
                else
                    print_error "Failed to clone $service_name (exit code: $CLONE_EXIT)"
                    print_info "URL: $repo_url"
                    print_info "Check the URL and your network connection"
                fi
            else
                # Repository URL not configured
                if [ -d "$full_path" ]; then
                    print_warning "$service_name: Directory is empty and no URL configured"
                else
                    print_warning "$service_name: Not found and no URL configured"
                fi
                print_info "Add ${env_var_name}=<url> to .env to enable auto-cloning"
                print_info "Or clone manually: git clone <url> $service_path"
            fi
        fi
    done
    
    echo ""
    if [ $CLONED_COUNT -gt 0 ] || [ $SKIPPED_COUNT -gt 0 ]; then
        print_success "Repository processing completed"
        if [ $CLONED_COUNT -gt 0 ]; then
            print_info "Cloned: $CLONED_COUNT service(s)"
        fi
        if [ $SKIPPED_COUNT -gt 0 ]; then
            print_info "Skipped: $SKIPPED_COUNT service(s) (already exist)"
        fi
    else
        print_warning "No services were processed"
    fi
else
    print_header "Step 2: Skipping Repository Cloning"
    print_info "Using existing service directories"
fi

# Step 3: Generate PKI infrastructure
if [ $SKIP_PKI -eq 0 ]; then
    print_header "Step 3: Generating PKI Infrastructure"
    
    print_info "Generating certificates for mTLS communication"
    print_info "This includes: 1 CA + 4 server + 16 client certificates"
    echo ""
    
    # Check if PKI scripts exist
    if [ ! -f "$PROJECT_ROOT/scripts/pki/01-generate-ca.sh" ]; then
        print_error "PKI scripts not found in scripts/pki/"
        print_info "Looking for scripts in: $PROJECT_ROOT/scripts/pki/"
        ls -la "$PROJECT_ROOT/scripts/pki/" 2>/dev/null || print_warning "scripts/pki/ directory does not exist"
        exit 1
    fi
    
    # Check if CA already exists
    if [ -f "$PROJECT_ROOT/volumes/pki/ca/ca.crt" ]; then
        print_warning "CA certificate already exists"
        read -p "$(echo -e "${YELLOW}?${NC} Regenerate PKI? This will invalidate all existing certificates [y/N]: ")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing PKI infrastructure"
            SKIP_PKI=1
        else
            print_step "Cleaning existing PKI..."
            "$PROJECT_ROOT/scripts/pki/clean-pki.sh" --yes
        fi
    fi
    
    if [ $SKIP_PKI -eq 0 ]; then
        # Generate CA
        print_step "Generating Root CA..."
        if "$PROJECT_ROOT/scripts/pki/01-generate-ca.sh"; then
            print_success "Root CA generated"
        else
            print_error "Failed to generate Root CA"
            exit 1
        fi
        
        echo ""
        
        # Generate server certificates
        print_step "Generating server certificates..."
        if "$PROJECT_ROOT/scripts/pki/02-generate-server-certs.sh"; then
            print_success "Server certificates generated"
        else
            print_error "Failed to generate server certificates"
            exit 1
        fi
        
        echo ""
        
        # Generate client certificates
        print_step "Generating client certificates..."
        if "$PROJECT_ROOT/scripts/pki/03-generate-client-certs.sh"; then
            print_success "Client certificates generated"
        else
            print_error "Failed to generate client certificates"
            exit 1
        fi
        
        echo ""
        print_success "PKI infrastructure generated successfully!"
        
        # Count generated certificates
        CERT_COUNT=$(find "$PROJECT_ROOT/volumes/pki" -name "*.crt" | wc -l)
        KEY_COUNT=$(find "$PROJECT_ROOT/volumes/pki" -name "*.key" | wc -l)
        print_info "Generated: $CERT_COUNT certificates, $KEY_COUNT private keys"
    fi
else
    print_header "Step 3: Skipping PKI Generation"
    print_info "Using existing PKI infrastructure"
    
    # Verify PKI exists
    if [ ! -f "$PROJECT_ROOT/volumes/pki/ca/ca.crt" ]; then
        print_error "CA certificate not found!"
        print_info "Run without --skip-pki to generate certificates"
        exit 1
    fi
fi

# Step 4: Initialize service configurations
print_header "Step 4: Initializing Service Configurations"

print_info "Checking service configuration files..."

# Check for example configs and create if needed
if [ -d "$PROJECT_ROOT/services/cts-core" ] && [ -f "$PROJECT_ROOT/services/cts-core/conf/config.example.ini" ]; then
    if [ ! -f "$PROJECT_ROOT/services/cts-core/conf/config.ini" ]; then
        print_step "Creating cts-core config from example..."
        cp "$PROJECT_ROOT/services/cts-core/conf/config.example.ini" "$PROJECT_ROOT/services/cts-core/conf/config.ini"
        print_success "cts-core config created"
    else
        print_info "cts-core config already exists"
    fi
fi

if [ -d "$PROJECT_ROOT/services/hsm-service" ] && [ -f "$PROJECT_ROOT/services/hsm-service/config.example.yaml" ]; then
    if [ ! -f "$PROJECT_ROOT/services/hsm-service/config.yaml" ]; then
        print_step "Creating hsm-service config from example..."
        cp "$PROJECT_ROOT/services/hsm-service/config.example.yaml" "$PROJECT_ROOT/services/hsm-service/config.yaml"
        print_success "hsm-service config created"
    else
        print_info "hsm-service config already exists"
    fi
fi

if [ -d "$PROJECT_ROOT/services/trader-daemon" ] && [ -f "$PROJECT_ROOT/services/trader-daemon/conf/config.example.ini" ]; then
    if [ ! -f "$PROJECT_ROOT/services/trader-daemon/conf/config.ini" ]; then
        print_step "Creating trader-daemon config from example..."
        cp "$PROJECT_ROOT/services/trader-daemon/conf/config.example.ini" "$PROJECT_ROOT/services/trader-daemon/conf/config.ini"
        print_success "trader-daemon config created"
    else
        print_info "trader-daemon config already exists"
    fi
fi

if [ -d "$PROJECT_ROOT/services/web-ui-go" ] && [ -f "$PROJECT_ROOT/services/web-ui-go/config/config.example.yaml" ]; then
    if [ ! -f "$PROJECT_ROOT/services/web-ui-go/config/config.yaml" ]; then
        print_step "Creating web-ui config from example..."
        cp "$PROJECT_ROOT/services/web-ui-go/config/config.example.yaml" "$PROJECT_ROOT/services/web-ui-go/config/config.yaml"
        print_success "web-ui config created"
    else
        print_info "web-ui config already exists"
    fi
fi

echo ""
print_success "Service configurations initialized"

# Step 5: Start Docker Compose
if [ $SKIP_DOCKER -eq 0 ]; then
    print_header "Step 5: Starting Docker Compose Services"
    
    # Check which service directories exist and are not empty
    print_step "Checking which services are available..."
    echo ""
    
    # Check if docker-compose.yml exists
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found!"
        exit 1
    fi
    
    # Define services and check which ones to start
    declare -a AVAILABLE_SERVICES=()
    declare -a UNAVAILABLE_SERVICES=()
    
    # MySQL is always available (built-in service, not cloned)
    AVAILABLE_SERVICES+=("mysql")
    
    # Check cloned services
    if [ -d "$PROJECT_ROOT/services/cts-core" ] && [ -n "$(ls -A "$PROJECT_ROOT/services/cts-core" 2>/dev/null)" ]; then
        print_success "cts-core: Available"
        AVAILABLE_SERVICES+=("cts-core")
    else
        print_warning "cts-core: Directory empty or missing (skipping)"
        UNAVAILABLE_SERVICES+=("cts-core")
    fi
    
    if [ -d "$PROJECT_ROOT/services/hsm-service" ] && [ -n "$(ls -A "$PROJECT_ROOT/services/hsm-service" 2>/dev/null)" ]; then
        print_success "hsm-service: Available"
        AVAILABLE_SERVICES+=("hsm-service")
    else
        print_warning "hsm-service: Directory empty or missing (skipping)"
        UNAVAILABLE_SERVICES+=("hsm-service")
    fi
    
    if [ -d "$PROJECT_ROOT/services/trader-daemon" ] && [ -n "$(ls -A "$PROJECT_ROOT/services/trader-daemon" 2>/dev/null)" ]; then
        print_success "trader-daemon: Available"
        AVAILABLE_SERVICES+=("trader-daemon")
    else
        print_warning "trader-daemon: Directory empty or missing (skipping)"
        UNAVAILABLE_SERVICES+=("trader-daemon")
    fi
    
    if [ -d "$PROJECT_ROOT/services/web-ui-go" ] && [ -n "$(ls -A "$PROJECT_ROOT/services/web-ui-go" 2>/dev/null)" ]; then
        print_success "web-ui-go: Available"
        AVAILABLE_SERVICES+=("web-ui-go")
    else
        print_warning "web-ui-go: Directory empty or missing (skipping)"
        UNAVAILABLE_SERVICES+=("web-ui-go")
    fi
    
    echo ""
    
    if [ ${#AVAILABLE_SERVICES[@]} -eq 0 ]; then
        print_error "No services available to start"
        exit 1
    fi
    
    print_step "Starting services: ${AVAILABLE_SERVICES[*]}"
    echo ""
    cd "$PROJECT_ROOT"
    
    if $DOCKER_COMPOSE_CMD up -d "${AVAILABLE_SERVICES[@]}"; then
        echo ""
        print_success "Services started successfully!"
        print_info "Started: ${AVAILABLE_SERVICES[*]}"
        
        if [ ${#UNAVAILABLE_SERVICES[@]} -gt 0 ]; then
            echo ""
            print_info "Not started (missing): ${UNAVAILABLE_SERVICES[*]}"
            print_info "To add them, clone their repositories and run again"
        fi
    else
        echo ""
        print_error "Failed to start services"
        print_info "Check docker-compose.yml and service configurations"
        exit 1
    fi
    
    # Wait a bit for services to initialize
    print_step "Waiting for services to initialize..."
    sleep 5
    
    # Check if MySQL is running and initialize database if needed
    print_header "Step 6: Initializing MySQL Database"
    
    if [[ " ${AVAILABLE_SERVICES[*]} " =~ " mysql " ]]; then
        # MySQL is running, check for init SQL
        INIT_SQL_FILE="$PROJECT_ROOT/volumes/mysql-dump/init.sql"
        
        if [ -f "$INIT_SQL_FILE" ]; then
            print_step "Found init.sql, initializing database..."
            
            # Wait for MySQL to be ready
            print_step "Waiting for MySQL to be ready..."
            for i in {1..30}; do
                if $DOCKER_COMPOSE_CMD exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root_dev_password_change_in_production}" -e "SELECT 1" &>/dev/null; then
                    print_success "MySQL is ready"
                    break
                fi
                if [ $i -eq 30 ]; then
                    print_error "MySQL failed to start within 30 seconds"
                    exit 1
                fi
                sleep 1
            done
            
            # Create database
            print_step "Creating database cts-system..."
            if $DOCKER_COMPOSE_CMD exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root_dev_password_change_in_production}" -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE:-ct_system} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" &>/dev/null; then
                print_success "Database created"
            else
                print_error "Failed to create database"
                exit 1
            fi
            
            # Load initial data
            print_step "Loading initial data from init.sql..."
            if $DOCKER_COMPOSE_CMD exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root_dev_password_change_in_production}" "${MYSQL_DATABASE:-ct_system}" < "$INIT_SQL_FILE" &>/dev/null; then
                print_success "Initial data loaded successfully"
            else
                print_error "Failed to load initial data"
                exit 1
            fi
        else
            print_info "init.sql not found at $INIT_SQL_FILE"
            print_info "To initialize database later, run:"
            echo "  docker compose exec mysql mysql -u root -p < volumes/mysql-dump/init.sql"
        fi
        
        # Create database users and grant privileges
        print_step "Creating database users..."
        
        # Create cts-core user
        if $DOCKER_COMPOSE_CMD exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root_dev_password_change_in_production}" -e \
            "CREATE USER IF NOT EXISTS 'cts-core'@'%' IDENTIFIED BY 'cts-core'; \
             GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE:-ct_system}.* TO 'cts-core'@'%'; \
             FLUSH PRIVILEGES;" &>/dev/null; then
            print_success "User 'cts-core' created with full privileges on ${MYSQL_DATABASE:-ct_system}"
        else
            print_error "Failed to create user 'cts-core'"
            exit 1
        fi
        
        # Create cts-web user
        if $DOCKER_COMPOSE_CMD exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-root_dev_password_change_in_production}" -e \
            "CREATE USER IF NOT EXISTS 'cts-web'@'%' IDENTIFIED BY 'cts-web'; \
             GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE:-ct_system}.* TO 'cts-web'@'%'; \
             FLUSH PRIVILEGES;" &>/dev/null; then
            print_success "User 'cts-web' created with full privileges on ${MYSQL_DATABASE:-ct_system}"
        else
            print_error "Failed to create user 'cts-web'"
            exit 1
        fi
    fi
    
    # Check service health
    print_header "Step 7: Checking Service Health"
    
    print_step "Checking running containers..."
    $DOCKER_COMPOSE_CMD ps
    
    echo ""
    print_info "To view logs: make logs or docker compose logs -f"
    print_info "To stop services: make down or docker compose down"
else
    print_header "Step 5: Skipping Docker Compose Startup"
    print_info "Services not started"
    print_info "To start manually: docker compose up -d <service-name>"
fi

# Summary
print_header "🎉 Initialization Complete!"

echo ""
print_success "CT-System development environment is ready!"
echo ""

print_info "Summary:"
echo "  ✓ Prerequisites checked"
echo "  ✓ PKI infrastructure prepared"
echo "  ✓ Service configurations initialized"
if [ $SKIP_DOCKER -eq 0 ]; then
    echo "  ✓ Docker services started"
fi

echo ""
print_info "Next steps:"
echo "  1. Configure service settings in conf/ directories"
echo "  2. Check service logs: docker compose logs -f"
echo "  3. Access services:"
echo "     • MySQL:     localhost:3306"
echo "     • HSM:       https://localhost:8443"
echo "     • CTS-Core:  http://localhost:8080"
echo "  4. Review documentation in README.md and docs/"

echo ""
print_info "Useful commands:"
echo "  make ps        - List running services"
echo "  make logs      - View all logs"
echo "  make logs-core - View CTS-Core logs"
echo "  make logs-hsm  - View HSM logs"
echo "  make down      - Stop all services"
echo "  make restart   - Restart all services"
echo "  make help      - Show all Makefile commands"

echo ""
print_info "Project structure:"
echo "  • docker-compose.yml  - Service configuration"
echo "  • Makefile            - Convenient commands"
echo "  • services/           - All service repositories"
echo "  • volumes/pki/        - Generated certificates"
echo "  • docs/               - Additional documentation"

echo ""
print_warning "⚠️  Security reminder:"
echo "  • Generated certificates are for DEV only"
echo "  • Do not use self-signed CA in production"
echo "  • Protect private keys (already in .gitignore)"

echo ""
print_success "Happy trading! 🚀"
echo ""
print_info "📚 Documentation:"
echo "  • README.md - Start here!"
echo "  • docs/ - Additional guides"
echo "  • See services/*/DEVELOPMENT_PLAN.md for details"
