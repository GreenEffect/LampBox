#!/bin/bash

# ==============================================================================
# Docker LAMP Stack - Cross-Platform Initialization Script
# ==============================================================================
# Works on: Linux, macOS, Windows (Git Bash/WSL2)
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="Linux";;
        Darwin*)    OS="Mac";;
        CYGWIN*)    OS="Windows";;
        MINGW*)     OS="Windows";;
        MSYS*)      OS="Windows";;
        *)          OS="Unknown";;
    esac
    
    print_info "Detected OS: $OS"
}

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking prerequisites"
    
    local missing_deps=()
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists docker-compose && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies first."
        exit 1
    fi
    
    print_info "✓ Docker is installed"
    print_info "✓ Docker Compose is installed"
    echo ""
}

# Auto-detect UID and GID (Linux/Mac only)
detect_uid_gid() {
    if [ "$OS" = "Windows" ]; then
        print_info "Windows detected: Using default UID/GID (1000:1000)"
        print_info "File permissions are handled automatically by Docker Desktop on Windows"
        DETECTED_UID=1000
        DETECTED_GID=1000
    else
        DETECTED_UID=$(id -u)
        DETECTED_GID=$(id -g)
        print_info "Detected UID: $DETECTED_UID"
        print_info "Detected GID: $DETECTED_GID"
    fi
}

# Create .env file from sample
create_env_file() {
    print_header "Environment Configuration"
    
    if [ -f .env ]; then
        print_warning ".env file already exists!"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return
        fi
    fi
    
    if [ ! -f sample.env ]; then
        print_error "sample.env not found!"
        exit 1
    fi
    
    # Copy sample.env to .env
    cp sample.env .env
    
    # Generate phpMyAdmin Blowfish secret if not set
    if command_exists openssl || command_exists head; then
        BLOWFISH_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p 2>/dev/null || echo "$(date +%s)_random_$(($RANDOM$RANDOM))")
        # Escape special characters for sed
        BLOWFISH_SECRET_ESCAPED=$(echo "$BLOWFISH_SECRET" | sed 's/[\/&]/\\&/g')
        if [ "$OS" = "Mac" ]; then
            sed -i '' "s/PHPMYADMIN_BLOWFISH_SECRET=$/PHPMYADMIN_BLOWFISH_SECRET=${BLOWFISH_SECRET_ESCAPED}/" .env
        else
            sed -i "s/PHPMYADMIN_BLOWFISH_SECRET=$/PHPMYADMIN_BLOWFISH_SECRET=${BLOWFISH_SECRET_ESCAPED}/" .env
        fi
        print_info "✓ Generated phpMyAdmin Blowfish secret"
    fi
    
    # Update UID/GID based on OS
    if [ "$OS" != "Windows" ]; then
        # On Linux/Mac, set the detected UID/GID
        if command_exists sed; then
            # Use sed for replacement
            if [ "$OS" = "Mac" ]; then
                # macOS sed syntax
                sed -i '' "s/USER_ID=1000/USER_ID=$DETECTED_UID/" .env
                sed -i '' "s/GROUP_ID=1000/GROUP_ID=$DETECTED_GID/" .env
            else
                # Linux sed syntax
                sed -i "s/USER_ID=1000/USER_ID=$DETECTED_UID/" .env
                sed -i "s/GROUP_ID=1000/GROUP_ID=$DETECTED_GID/" .env
            fi
        fi
    fi
    # On Windows, leave USER_ID/GROUP_ID as 1000 (default)
    
    print_info "✓ .env file created"
    if [ "$OS" != "Windows" ]; then
        print_info "✓ UID/GID configured for your user"
    fi
    echo ""
}

# Create necessary directories
create_directories() {
    print_header "Creating directories"
    
    local dirs=(
        "www"
        "data/mysql"
        "logs/apache2"
        "logs/mysql"
        "logs/nginx"
        "config/ssl"
        "config/nginx/ssl"
        "config/initdb"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_info "✓ Created $dir"
        fi
    done
    
    echo ""
}

# Set proper permissions (Linux/Mac only)
set_permissions() {
    print_header "Setting permissions"
    
    if [ "$OS" = "Windows" ]; then
        print_info "On Windows, Docker Desktop handles permissions automatically"
        print_info "No manual permission configuration needed"
    else
        # Set permissions for Linux/Mac
        if [ -d "data/mysql" ]; then
            chmod 755 data/mysql 2>/dev/null || true
            print_info "✓ Set permissions for data/mysql"
        fi
        
        if [ -d "www" ]; then
            chmod 755 www 2>/dev/null || true
            print_info "✓ Set permissions for www"
        fi
        
        if [ -d "logs" ]; then
            chmod 755 logs 2>/dev/null || true
            chmod 755 logs/* 2>/dev/null || true
            print_info "✓ Set permissions for logs"
        fi
        
        # Fix phpMyAdmin config permissions (security requirement)
        if [ -f "config/phpmyadmin/config.inc.php" ]; then
            chmod 644 config/phpmyadmin/config.inc.php 2>/dev/null || true
            print_info "✓ Set permissions for phpMyAdmin config"
        fi
    fi
    
    echo ""
}

# Display configuration summary
show_summary() {
    print_header "Configuration Summary"
    
    # Load .env to show current config
    if [ -f .env ]; then
        source .env
        
        echo -e "${BLUE}Operating System:${NC} $OS"
        echo -e "${BLUE}Project:${NC} $COMPOSE_PROJECT_NAME"
        echo -e "${BLUE}PHP Version:${NC} $PHPVERSION"
        echo -e "${BLUE}Database:${NC} $DATABASE"
        echo -e "${BLUE}Reverse Proxy:${NC} $USE_REVERSE_PROXY"
        
        if [ "$OS" != "Windows" ]; then
            echo -e "${BLUE}USER_ID:GROUP_ID:${NC} $USER_ID:$GROUP_ID"
        fi
        
        if [ "$USE_REVERSE_PROXY" = "true" ]; then
            echo -e "${BLUE}Domain:${NC} https://$PROJECT_DOMAIN"
        else
            echo -e "${BLUE}HTTP Port:${NC} http://localhost:$HTTP_PORT"
            echo -e "${BLUE}HTTPS Port:${NC} https://localhost:$HTTPS_PORT"
        fi
        
        echo ""
    fi
}

# Display next steps
show_next_steps() {
    print_header "Next Steps"
    
    source .env
    
    echo "1. Review and customize your .env file if needed:"
    if [ "$OS" = "Windows" ]; then
        echo -e "   ${YELLOW}notepad .env${NC}"
    else
        echo -e "   ${YELLOW}nano .env${NC}"
    fi
    echo ""
    
    if [ "$USE_REVERSE_PROXY" = "true" ]; then
        echo "2. Add this line to your hosts file:"
        if [ "$OS" = "Windows" ]; then
            echo -e "   File: ${YELLOW}C:\\Windows\\System32\\drivers\\etc\\hosts${NC}"
            echo -e "   Line: ${YELLOW}127.0.0.1    $PROJECT_DOMAIN${NC}"
            echo "   (Run Notepad as Administrator to edit)"
        else
            echo -e "   File: ${YELLOW}/etc/hosts${NC}"
            echo -e "   Command: ${YELLOW}echo '127.0.0.1    $PROJECT_DOMAIN' | sudo tee -a /etc/hosts${NC}"
        fi
        echo ""
        echo "3. Generate SSL certificates:"
        if [ "$OS" = "Windows" ]; then
            echo -e "   ${YELLOW}bash generate-ssl-certs.sh${NC} (in Git Bash)"
        else
            echo -e "   ${YELLOW}./generate-ssl-certs.sh${NC}"
        fi
        echo ""
        echo "4. Start your stack with reverse proxy:"
        echo -e "   ${YELLOW}docker compose --profile proxy up -d${NC}"
        echo ""
        echo "5. Access your site:"
        echo -e "   ${YELLOW}https://$PROJECT_DOMAIN${NC}"
    else
        echo "2. Start your stack:"
        echo -e "   ${YELLOW}docker compose up -d${NC}"
        echo ""
        echo "3. Access your site:"
        echo -e "   ${YELLOW}http://localhost:$HTTP_PORT${NC}"
        echo ""
        echo "4. Access phpMyAdmin:"
        echo -e "   ${YELLOW}http://localhost:$HTTP_PORT/${COMPOSE_PROJECT_NAME}-mysql${NC}"
    fi
    
    echo ""
    
    if [ "$OS" = "Windows" ]; then
        print_warning "Windows Notes:"
        echo "  - Use Git Bash or WSL2 for bash scripts"
        echo "  - Docker Desktop must be running"
        echo "  - File permissions are handled automatically"
        echo ""
    fi
    
    print_info "To enable reverse proxy mode, edit .env and set:"
    echo -e "   ${YELLOW}USE_REVERSE_PROXY=true${NC}"
    echo -e "   ${YELLOW}PROJECT_DOMAIN=myproject.local${NC}"
    echo ""
}

# Main execution
main() {
    print_header "Docker LAMP Stack - Cross-Platform Initialization"
    echo ""
    
    detect_os
    echo ""
    check_prerequisites
    detect_uid_gid
    echo ""
    create_env_file
    create_directories
    set_permissions
    show_summary
    show_next_steps
    
    print_info "✓ Initialization complete!"
}

# Run main function
main