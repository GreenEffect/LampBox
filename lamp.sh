#!/bin/bash

# ==============================================================================
# LampBox - Management Script
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

compose_files() {
    local args=(docker compose -f docker-compose.yml)

    if [ "$USE_REVERSE_PROXY" = "true" ]; then
        args+=( -f docker-compose.proxy.yml )
    fi

    # The database has no host port by default; publish one only if requested
    if [ -n "$MYSQL_PORT" ]; then
        args+=( -f docker-compose.mysql-port.yml )
    fi

    echo "${args[@]}"
}

# Shared Traefik reverse proxy management
PROXY_NETWORK="${PROXY_NETWORK:-lampbox_web}"
TRAEFIK_COMPOSE="traefik/docker-compose.yml"

# Ensure the shared network, TLS certificate and Traefik container are ready.
ensure_proxy() {
    # Create the shared external network if it does not exist yet
    if ! docker network inspect "$PROXY_NETWORK" >/dev/null 2>&1; then
        print_info "Creating shared proxy network: $PROXY_NETWORK"
        docker network create "$PROXY_NETWORK" >/dev/null
    fi

    # Ensure the shared TLS certificate exists
    if [ ! -f "traefik/certs/cert.pem" ]; then
        print_warning "Shared TLS certificate not found!"
        print_info "Generating shared *.local certificate..."
        ./traefik/generate-certs.sh
    fi

    # Ensure the shared Traefik container is running
    if ! docker ps --format '{{.Names}}' | grep -q '^lampbox-traefik$'; then
        print_info "Starting shared Traefik reverse proxy..."
        docker compose -f "$TRAEFIK_COMPOSE" up -d
    fi
}

# Start the shared Traefik reverse proxy
proxy_up() {
    print_header "Starting shared Traefik reverse proxy"
    ensure_proxy
    print_info "✓ Traefik is running and owns ports 80/443"
    print_info "Dashboard (add traefik.local to your hosts file): https://traefik.local"
}

# Stop the shared Traefik reverse proxy
proxy_down() {
    print_header "Stopping shared Traefik reverse proxy"
    docker compose -f "$TRAEFIK_COMPOSE" down
    print_info "✓ Traefik stopped"
    print_warning "Running projects lose HTTPS routing until Traefik is started again."
}

mysql_data_exists() {
    if [ ! -d "data/mysql" ]; then
        return 1
    fi

    shopt -s nullglob 2>/dev/null
    local files=(data/mysql/*)
    shopt -u nullglob

    for file in "${files[@]}"; do
        case "$(basename "$file")" in
            .gitkeep|.db_version)
                continue
                ;;
            *)
                return 0
                ;;
        esac
    done

    return 1
}

check_mysql_data() {
    if mysql_data_exists; then
        if [ -f "data/mysql/.db_version" ]; then
            local existing_version
            existing_version=$(cat data/mysql/.db_version)
            if [ "$existing_version" != "$DATABASE" ]; then
                print_error "Existing MySQL data was created for '$existing_version' but current DATABASE is '$DATABASE'."
                print_error "Run './lamp.sh clean-db' before switching database engines."
                exit 1
            fi
        else
            print_warning "Existing MySQL data directory contains files and no version marker."
            print_warning "This may cause startup failures if the data folder is incompatible with '$DATABASE'."
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Aborting startup. Use './lamp.sh clean-db' to reset the database data."
                exit 1
            fi
        fi
    fi
}

# Show usage
usage() {
    cat << EOF
${BLUE}LampBox - Management Script${NC}

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
  ssl             Generate the shared Traefik TLS certificate (*.local)
  proxy-up        Start the shared Traefik reverse proxy (owns ports 80/443)
  proxy-down      Stop the shared Traefik reverse proxy
  info            Show connection information

${GREEN}Options:${NC}
  --proxy, -p     Use reverse proxy mode (for start/restart)
  --follow, -f    Follow logs in real-time (for logs command)

${GREEN}Examples:${NC}
  $0 proxy-up             Start the shared Traefik proxy (once for all projects)
  $0 start                Start in direct port mode
  $0 start --proxy        Start behind Traefik (multi-project reverse proxy)
  $0 logs -f              Follow all logs
  $0 logs webserver       Show webserver logs only
  $0 shell                Open shell in webserver
  $0 mysql                Open MySQL command line

EOF
}

# Start the stack
start() {
    check_env
    check_mysql_data
    print_header "Starting LampBox: $COMPOSE_PROJECT_NAME"
    
    if [ "$1" = "--proxy" ] || [ "$1" = "-p" ] || [ "$USE_REVERSE_PROXY" = "true" ]; then
        print_info "Starting with reverse proxy mode (Traefik)..."

        # Ensure the shared Traefik proxy, network and TLS certificate are ready
        ensure_proxy

        local COMPOSE_CMD=($(compose_files))
        "${COMPOSE_CMD[@]}" up -d
        print_info "✓ Stack started behind Traefik"
        print_info "Access your site at: https://$PROJECT_DOMAIN"
        print_warning "Make sure '$PROJECT_DOMAIN' points to 127.0.0.1 in your hosts file."
    else
        print_info "Starting in direct port mode..."
        local COMPOSE_CMD=($(compose_files))
        "${COMPOSE_CMD[@]}" up -d
        print_info "✓ Stack started"
        print_info "Access your site at: http://localhost:$HTTP_PORT"
    fi
    
    echo ""
    status
}

# Stop the stack
stop() {
    check_env
    print_header "Stopping LampBox: $COMPOSE_PROJECT_NAME"
    local COMPOSE_CMD=($(compose_files))
    "${COMPOSE_CMD[@]}" down
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
    print_header "Rebuilding LampBox"
    print_warning "This will rebuild all containers from scratch"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local COMPOSE_CMD=($(compose_files))
        "${COMPOSE_CMD[@]}" down
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
    print_header "Cleaning LampBox"
    print_warning "This will remove all containers, networks, and volumes!"
    print_warning "Your database data will be LOST unless backed up!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local COMPOSE_CMD=($(compose_files))
        "${COMPOSE_CMD[@]}" down -v
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

# Generate the shared Traefik TLS certificate
generate_ssl() {
    print_info "Generating shared Traefik TLS certificate (*.local)..."
    ./traefik/generate-certs.sh
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
    proxy-up)
        proxy_up
        ;;
    proxy-down)
        proxy_down
        ;;
    info)
        show_info
        ;;
    *)
        usage
        exit 1
        ;;
esac
