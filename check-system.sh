#!/bin/bash

# ==============================================================================
# LampBox - System Check Script
# ==============================================================================
# Verifies that your system meets all requirements
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}"
}

print_check() {
    echo -n "Checking $1... "
}

print_ok() {
    echo -e "${GREEN}✓ OK${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC} $1"
}

print_error() {
    echo -e "${RED}✗ ERROR${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ INFO${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check function that tracks errors
check_count=0
error_count=0
warning_count=0

run_check() {
    check_count=$((check_count + 1))
}

mark_error() {
    error_count=$((error_count + 1))
}

mark_warning() {
    warning_count=$((warning_count + 1))
}

# Main checks
print_header "System Requirements Check"
echo ""

# 1. Check OS
run_check
print_check "Operating System"
OS=$(uname -s)
case "$OS" in
    Linux*)
        print_ok "Linux detected"
        ;;
    Darwin*)
        print_ok "macOS detected"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        print_warning "Windows detected - WSL2 recommended"
        mark_warning
        ;;
    *)
        print_error "Unknown OS: $OS"
        mark_error
        ;;
esac

# 2. Check Docker
run_check
print_check "Docker"
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    print_ok "Docker $DOCKER_VERSION installed"
    
    # Check if Docker daemon is running
    if docker ps &> /dev/null; then
        print_ok "Docker daemon is running"
    else
        print_error "Docker daemon is not running"
        mark_error
    fi
else
    print_error "Docker is not installed"
    print_info "Install from: https://docs.docker.com/get-docker/"
    mark_error
fi

# 3. Check Docker Compose
run_check
print_check "Docker Compose"
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    print_ok "Docker Compose v2 ($COMPOSE_VERSION) installed"
elif command_exists docker-compose; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
    print_ok "Docker Compose v1 ($COMPOSE_VERSION) installed"
    print_warning "Consider upgrading to Docker Compose v2"
    mark_warning
else
    print_error "Docker Compose is not installed"
    print_info "Install from: https://docs.docker.com/compose/install/"
    mark_error
fi

# 4. Check available ports
run_check
print_check "Port availability"
PORTS_TO_CHECK=(80 443 8080 8443 3306)
PORTS_IN_USE=()

for port in "${PORTS_TO_CHECK[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t &> /dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        PORTS_IN_USE+=($port)
    fi
done

if [ ${#PORTS_IN_USE[@]} -eq 0 ]; then
    print_ok "All common ports are available"
else
    print_warning "Ports in use: ${PORTS_IN_USE[*]}"
    print_info "You can configure different ports in .env file"
    mark_warning
fi

# 5. Check disk space
run_check
print_check "Disk space"
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')

if [ "$AVAILABLE_SPACE_GB" -ge 5 ]; then
    print_ok "$AVAILABLE_SPACE available"
else
    print_warning "Only $AVAILABLE_SPACE available (5GB+ recommended)"
    mark_warning
fi

# 6. Check memory
run_check
print_check "System memory"
if [ -f /proc/meminfo ]; then
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM / 1024 / 1024))
    
    if [ "$TOTAL_MEM_GB" -ge 4 ]; then
        print_ok "${TOTAL_MEM_GB}GB RAM available"
    else
        print_warning "${TOTAL_MEM_GB}GB RAM (4GB+ recommended)"
        mark_warning
    fi
elif command_exists sysctl; then
    TOTAL_MEM=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    TOTAL_MEM_GB=$((TOTAL_MEM / 1024 / 1024 / 1024))
    
    if [ "$TOTAL_MEM_GB" -ge 4 ]; then
        print_ok "${TOTAL_MEM_GB}GB RAM available"
    else
        print_warning "${TOTAL_MEM_GB}GB RAM (4GB+ recommended)"
        mark_warning
    fi
else
    print_warning "Cannot determine memory"
    mark_warning
fi

# 7. Check Docker permissions
run_check
print_check "Docker permissions"
if docker ps &> /dev/null; then
    print_ok "User has Docker permissions"
else
    if [ "$OS" = "Linux" ]; then
        print_error "User cannot run Docker without sudo"
        print_info "Add user to docker group: sudo usermod -aG docker \$USER"
        print_info "Then logout and login again"
        mark_error
    else
        print_warning "Docker permissions issue"
        mark_warning
    fi
fi

# 8. Check Git (optional but recommended)
run_check
print_check "Git"
if command_exists git; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    print_ok "Git $GIT_VERSION installed"
else
    print_warning "Git is not installed (recommended for version control)"
    mark_warning
fi

# 9. Check text editor
run_check
print_check "Text editor"
if command_exists nano; then
    print_ok "nano is available"
elif command_exists vim; then
    print_ok "vim is available"
elif command_exists vi; then
    print_ok "vi is available"
else
    print_warning "No common text editor found"
    mark_warning
fi

# 10. Check openssl (for SSL cert generation)
run_check
print_check "OpenSSL"
if command_exists openssl; then
    OPENSSL_VERSION=$(openssl version | cut -d' ' -f2)
    print_ok "OpenSSL $OPENSSL_VERSION installed"
else
    print_warning "OpenSSL not found (needed for SSL certificate generation)"
    print_info "Install: sudo apt-get install openssl (Linux) or brew install openssl (Mac)"
    mark_warning
fi

# 11. Check for required files
run_check
print_check "Required files"
REQUIRED_FILES=(
    "docker-compose.yml"
    "sample.env"
    "init.sh"
    "lamp.sh"
    "generate-ssl-certs.sh"
)

missing_files=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    print_ok "All required files present"
else
    print_error "Missing files: ${missing_files[*]}"
    mark_error
fi

# Summary
echo ""
print_header "Summary"
echo ""

echo -e "Total checks: $check_count"

if [ $error_count -eq 0 ] && [ $warning_count -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your system is ready to run LampBox."
    echo ""
    echo "Next steps:"
    echo "  1. ./init.sh           # Initialize your environment"
    echo "  2. nano .env            # Customize configuration (optional)"
    echo "  3. ./lamp.sh start     # Start your LAMP stack"
    echo ""
elif [ $error_count -eq 0 ]; then
    echo -e "${YELLOW}⚠ ${warning_count} warning(s) found${NC}"
    echo ""
    echo "Your system should work, but consider fixing the warnings above."
    echo ""
    echo "You can proceed with:"
    echo "  ./init.sh"
    echo ""
else
    echo -e "${RED}✗ ${error_count} error(s) found${NC}"
    if [ $warning_count -gt 0 ]; then
        echo -e "${YELLOW}⚠ ${warning_count} warning(s) found${NC}"
    fi
    echo ""
    echo "Please fix the errors above before proceeding."
    echo ""
fi

exit $error_count
