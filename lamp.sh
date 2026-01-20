#!/bin/bash

# ==============================================================================
# Docker LAMP Stack - Management Script
# ==============================================================================
# Easy commands to start, stop, and manage your LAMP stack
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}$1${NC}"; }

# Check if .env exists
check_env() {
    if [ ! -f .env ]; then
        print_error ".env file not found!"
        print_info "Run './init.sh' first to initialize your environment."
        exit 1
    fi
    source .env
}

# Show usage
usage() {
    cat << EOF
${BLUE}Docker LAMP Stack - Management Script${NC}

Usage: $0 [COMMAND] [OPTIONS]

${GREEN}Commands:${NC}
  start           Start the LAMP stack
  stop            Stop the LAMP stack
  restart         Restart the LAMP stack
  status          Show status of all containers
  logs            Show logs (use -f to follow)
  shell           Open bash shell in webserver container
  mysql           Open MySQL shell
  rebuild         Rebuild and restart containers
  clean           Stop and remove all containers, networks, and volumes
  clean-db        Clean MySQL data directory only (fix initialization errors)
  ssl             Generate SSL certificates
  info            Show connection information

${GREEN}Options:${NC}
  --proxy, -p     Use reverse proxy mode (for start/restart)
  --follow, -f    Follow logs in real-time (for logs command)

${GREEN}Examples:${NC}
  $0 start                Start in direct port mode
  $0 start --proxy        Start with reverse proxy
  $0 logs -f              Follow all logs
  $0 logs webserver       Show webserver logs only
  $0 shell                Open shell in webserver
  $0 mysql                Open MySQL command line

EOF
}

# Start the stack
start() {
    check_env
    print_header "Starting Docker LAMP Stack: $COMPOSE_PROJECT_NAME"
    
    if [ "$1" = "--proxy" ] || [ "$1" = "-p" ] || [ "$USE_REVERSE_PROXY" = "true" ]; then
        print_info "Starting with reverse proxy mode..."
        
        # Check if SSL certificates exist
        if [ ! -f "config/nginx/ssl/cert.pem" ]; then
            print_warning "SSL certificates not found!"
            print_info "Generating SSL certificates..."
            ./generate-ssl-certs.sh
        fi
        
        docker compose --profile proxy up -d
        print_info "✓ Stack started with reverse proxy"
        print_info "Access your site at: https://$PROJECT_DOMAIN"
    else
        print_info "Starting in direct port mode..."
        docker compose up -d
        print_info "✓ Stack started"
        print_info "Access your site at: http://localhost:$HTTP_PORT"
    fi
    
    echo ""
    status
}

# Stop the stack
stop() {
    check_env
    print_header "Stopping Docker LAMP Stack: $COMPOSE_PROJECT_NAME"
    docker compose --profile proxy down
    print_info "✓ Stack stopped"
}

# Restart the stack
restart() {
    stop
    echo ""
    start "$@"
}

# Show status
status() {
    check_env
    print_header "Container Status"
    docker compose ps
}

# Show logs
logs() {
    check_env
    local service="$1"
    local follow=""
    
    # Check for follow flag
    if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
        follow="-f"
        service="$2"
    elif [ "$2" = "-f" ] || [ "$2" = "--follow" ]; then
        follow="-f"
    fi
    
    if [ -n "$service" ] && [ "$service" != "-f" ] && [ "$service" != "--follow" ]; then
        print_info "Showing logs for: $service"
        docker compose logs $follow "$service"
    else
        print_info "Showing logs for all services"
        docker compose logs $follow
    fi
}

# Open shell in webserver
shell() {
    check_env
    print_info "Opening bash shell in webserver container..."
    docker compose exec webserver bash
}

# Open MySQL shell
mysql_shell() {
    check_env
    print_info "Opening MySQL shell..."
    docker compose exec database mysql -u root -p"$MYSQL_ROOT_PASSWORD"
}

# Rebuild containers
rebuild() {
    check_env
    print_header "Rebuilding Docker LAMP Stack"
    print_warning "This will rebuild all containers from scratch"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose --profile proxy down
        docker compose build --no-cache
        print_info "✓ Rebuild complete"
        echo ""
        start "$@"
    else
        print_info "Rebuild cancelled"
    fi
}

# Clean everything
clean() {
    check_env
    print_header "Cleaning Docker LAMP Stack"
    print_warning "This will remove all containers, networks, and volumes!"
    print_warning "Your database data will be LOST unless backed up!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose --profile proxy down -v
        print_info "✓ All containers, networks, and volumes removed"
        
        read -p "Also remove MySQL data directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf data/mysql/*
            print_info "✓ MySQL data directory cleaned"
        fi
    else
        print_info "Clean cancelled"
    fi
}

# Clean MySQL data directory only
clean_db() {
    check_env
    print_header "Cleaning MySQL Data Directory"
    print_warning "This will remove ALL database data!"
    print_warning "Make sure to backup if you have important data!"
    echo ""
    print_info "Use this if MySQL won't start due to 'data directory has files' error"
    echo ""
    read -p "Remove all MySQL data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stop database container if running
        docker compose stop database 2>/dev/null || true
        
        # Clean data directory
        rm -rf data/mysql/*
        print_info "✓ MySQL data directory cleaned"
        
        # Keep .gitkeep if exists
        touch data/mysql/.gitkeep 2>/dev/null || true
        
        echo ""
        print_info "You can now start fresh with: ./lamp.sh start"
    else
        print_info "Clean cancelled"
    fi
}

# Generate SSL certificates
generate_ssl() {
    check_env
    print_info "Generating SSL certificates..."
    ./generate-ssl-certs.sh
}

# Show connection info
show_info() {
    check_env
    print_header "Connection Information"
    
    echo ""
    echo -e "${BLUE}Project:${NC} $COMPOSE_PROJECT_NAME"
    echo -e "${BLUE}PHP Version:${NC} $PHPVERSION"
    echo -e "${BLUE}Database:${NC} $DATABASE"
    echo ""
    
    if [ "$USE_REVERSE_PROXY" = "true" ]; then
        echo -e "${GREEN}Website:${NC} https://$PROJECT_DOMAIN"
        echo -e "${GREEN}phpMyAdmin:${NC} https://$PROJECT_DOMAIN/${COMPOSE_PROJECT_NAME}-mysql"
    else
        echo -e "${GREEN}Website (HTTP):${NC} http://localhost:$HTTP_PORT"
        echo -e "${GREEN}Website (HTTPS):${NC} https://localhost:$HTTPS_PORT"
        echo -e "${GREEN}phpMyAdmin:${NC} http://localhost:$HTTP_PORT/${COMPOSE_PROJECT_NAME}-mysql"
    fi
    
    if [ -n "$MYSQL_PORT" ]; then
        echo -e "${GREEN}MySQL:${NC} localhost:$MYSQL_PORT"
    fi
    
    echo ""
    echo -e "${BLUE}Database Credentials:${NC}"
    echo -e "  Host: ${COMPOSE_PROJECT_NAME}-database (or localhost:$MYSQL_PORT from host)"
    echo -e "  Root Password: $MYSQL_ROOT_PASSWORD"
    echo -e "  Database: $MYSQL_DATABASE"
    echo -e "  User: $MYSQL_USER"
    echo -e "  Password: $MYSQL_PASSWORD"
    echo ""
}

# Main script
case "$1" in
    start)
        start "$2"
        ;;
    stop)
        stop
        ;;
    restart)
        restart "$2"
        ;;
    status)
        status
        ;;
    logs)
        logs "$2" "$3"
        ;;
    shell)
        shell
        ;;
    mysql)
        mysql_shell
        ;;
    rebuild)
        rebuild "$2"
        ;;
    clean)
        clean
        ;;
    clean-db)
        clean_db
        ;;
    ssl)
        generate_ssl
        ;;
    info)
        show_info
        ;;
    *)
        usage
        exit 1
        ;;
esac
