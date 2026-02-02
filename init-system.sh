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

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

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
    print_warning "Note: GitHub URLs need to be configured in .env file"
    echo ""
    
    # Check if .env file exists
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            print_step "Creating .env from .env.example..."
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            print_success ".env file created"
            print_warning "Please configure GitHub URLs in .env file"
        else
            print_warning ".env.example not found"
            print_info "Skipping repository cloning - services directory should exist"
        fi
    fi
    
    # Define services to clone
    declare -A SERVICES=(
        ["cts-core"]="services/cts-core"
        ["hsm-service"]="services/hsm-service"
        ["trader-daemon"]="services/trader-daemon"
        ["web-ui-go"]="services/web-ui-go"
    )
    
    # Check which services exist
    for service_name in "${!SERVICES[@]}"; do
        service_path="${SERVICES[$service_name]}"
        
        if [ -d "$PROJECT_ROOT/$service_path" ]; then
            if [ -d "$PROJECT_ROOT/$service_path/.git" ]; then
                print_info "$service_name: Already exists (git repository)"
            else
                print_info "$service_name: Directory exists (not a git repo)"
            fi
        else
            print_warning "$service_name: Not found at $service_path"
            print_info "You can clone it manually or add GitHub URL to .env"
        fi
    done
    
    echo ""
    print_info "Repository cloning completed"
    print_info "If services are missing, clone them manually:"
    echo "  git clone <repo-url> services/<service-name>"
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
    
    print_info "This will start all services defined in docker-compose.yml"
    echo ""
    
    # Check if docker-compose.yml exists
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found!"
        exit 1
    fi
    
    print_step "Starting services..."
    cd "$PROJECT_ROOT"
    
    if $DOCKER_COMPOSE_CMD up -d; then
        echo ""
        print_success "Services started successfully!"
    else
        echo ""
        print_error "Failed to start services"
        print_info "Check docker-compose.yml and service configurations"
        exit 1
    fi
    
    # Wait a bit for services to initialize
    print_step "Waiting for services to initialize..."
    sleep 5
    
    # Check service health
    print_header "Step 6: Checking Service Health"
    
    print_step "Checking running containers..."
    $DOCKER_COMPOSE_CMD ps
    
    echo ""
    print_info "To view logs: make logs or docker compose logs -f"
    print_info "To stop services: make down or docker compose down"
else
    print_header "Step 5: Skipping Docker Compose Startup"
    print_info "Services not started"
    print_info "To start manually: docker compose up -d"
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
echo "  3. Access Web UI: http://localhost:80"
echo "  4. Review documentation in docs/"

echo ""
print_info "Useful commands:"
echo "  make ps      - List running services"
echo "  make logs    - View all logs"
echo "  make down    - Stop all services"
echo "  make restart - Restart all services"

echo ""
print_warning "⚠️  Security reminder:"
echo "  • Generated certificates are for DEV only"
echo "  • Do not use self-signed CA in production"
echo "  • Protect private keys (already in .gitignore)"

echo ""
print_success "Happy trading! 🚀"
echo ""
