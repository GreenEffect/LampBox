#!/bin/bash

# ==============================================================================
# LampBox - Management Script
# ==============================================================================
# Easy commands to start, stop, and manage your LAMP stack
# ==============================================================================

set -e

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

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

    # A typo must not silently run development settings in production
    case "${LAMPBOX_ENV:-development}" in
        development|production) ;;
        *)
            print_error "LAMPBOX_ENV must be 'development' or 'production' (got '$LAMPBOX_ENV')"
            exit 1
            ;;
    esac
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

    # Production settings: php-production.ini, phpMyAdmin denied by default
    if [ "$LAMPBOX_ENV" = "production" ]; then
        args+=( -f docker-compose.production.yml )
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

# Database data directory, with the same default as docker-compose.yml
mysql_data_dir() {
    local dir="${MYSQL_DATA_DIR:-./data/mysql-${DATABASE}}"
    echo "${dir%/}"
}

# Engine marker, stored next to the data directory (e.g. data/mysql-mysql84.database).
# Never inside it: MySQL refuses to initialize a data directory that has files.
mysql_engine_marker() {
    echo "$(mysql_data_dir).database"
}

mysql_data_exists() {
    local dir
    dir=$(mysql_data_dir)
    [ -d "$dir" ] || return 1

    shopt -s nullglob dotglob 2>/dev/null
    local files=("$dir"/*)
    shopt -u nullglob dotglob

    for file in "${files[@]}"; do
        case "$(basename "$file")" in
            .gitkeep)
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
    local dir marker
    dir=$(mysql_data_dir)
    marker=$(mysql_engine_marker)

    # Some engines make the directory unreadable from the host (mode 750):
    # its content cannot be checked, so leave the marker as it is
    if [ -d "$dir" ] && { [ ! -r "$dir" ] || [ ! -x "$dir" ]; }; then
        return
    fi

    if ! mysql_data_exists; then
        # Fresh directory: it will be initialized by $DATABASE
        echo "$DATABASE" > "$marker" 2>/dev/null || true
        return
    fi

    if [ -f "$marker" ]; then
        local existing_version
        existing_version=$(cat "$marker")
        if [ "$existing_version" != "$DATABASE" ]; then
            print_error "Database data in '$dir' was created for '$existing_version' but DATABASE is '$DATABASE'."
            print_error "Switch back DATABASE, or run './lamp.sh dump' then './lamp.sh clean-db'."
            exit 1
        fi
        return
    fi

    # Default per-engine directory (data/mysql-<DATABASE>): the engine is known
    if [ "$(basename "$dir")" = "mysql-$DATABASE" ]; then
        echo "$DATABASE" > "$marker" 2>/dev/null || true
        return
    fi

    # Custom MYSQL_DATA_DIR without marker (e.g. projects created before 2.1.0):
    # ask once, then remember the answer
    print_warning "'$dir' contains database data of an unknown engine (DATABASE is '$DATABASE')."
    print_warning "Starting a different engine on it may fail or damage the data."
    read -p "Is this data from '$DATABASE'? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborting startup. Set DATABASE to the engine that created this data."
        exit 1
    fi
    echo "$DATABASE" > "$marker"
    print_info "Recorded engine in $marker"
}

# Empty the database data directory. Its files belong to the database user of
# the container, so they are deleted from a throwaway database container.
wipe_mysql_data() {
    local COMPOSE_CMD=($(compose_files))
    "${COMPOSE_CMD[@]}" stop database >/dev/null 2>&1 || true
    "${COMPOSE_CMD[@]}" run --rm --no-deps -T --entrypoint sh database \
        -c 'rm -rf /var/lib/mysql/* /var/lib/mysql/.[!.]* /var/lib/mysql/..?*'
    rm -f "$(mysql_engine_marker)"
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
  dump            Dump all databases to data/db-dumps/ (consistent backup)
  rebuild         Rebuild and restart containers
  update          Pull the latest PHP image and recreate the webserver only
  clean           Stop and remove all containers, networks, and volumes
  clean-db        Clean MySQL data directory only (fix initialization errors)
  ssl             Generate the shared Traefik TLS certificate (*.local)
  proxy-up        Start the shared Traefik reverse proxy (owns ports 80/443)
  proxy-down      Stop the shared Traefik reverse proxy
  info            Show connection information

${GREEN}Options:${NC}
  --proxy, -p     Use reverse proxy mode (for start/restart)
  --follow, -f    Follow logs in real-time (for logs command)
  --yes, -y       Do not ask for confirmation (for update)

${GREEN}Examples:${NC}
  $0 proxy-up             Start the shared Traefik proxy (once for all projects)
  $0 start                Start in direct port mode
  $0 start --proxy        Start behind Traefik (multi-project reverse proxy)
  $0 logs -f              Follow all logs
  $0 logs webserver       Show webserver logs only
  $0 shell                Open shell in webserver
  $0 mysql                Open MySQL command line
  $0 update               Apply a PHP security release (database untouched)

EOF
}

# Start the stack
start() {
    check_env
    check_mysql_data
    print_header "Starting LampBox: $COMPOSE_PROJECT_NAME"
    print_info "Environment: ${LAMPBOX_ENV:-development}"

    # Images are tagged per PHPVERSION and DATABASE (docker-compose.yml), so a
    # switch never reuses another version's image. up --build also applies
    # Dockerfile changes; unchanged images come from the build cache.

    # --proxy must also make compose_files() add docker-compose.proxy.yml
    if [ "$1" = "--proxy" ] || [ "$1" = "-p" ]; then
        USE_REVERSE_PROXY=true
    fi

    if [ "$USE_REVERSE_PROXY" = "true" ]; then
        print_info "Starting with reverse proxy mode (Traefik)..."

        # Ensure the shared Traefik proxy, network and TLS certificate are ready
        ensure_proxy

        local COMPOSE_CMD=($(compose_files))
        "${COMPOSE_CMD[@]}" up -d --build
        print_info "✓ Stack started behind Traefik"
        print_info "Access your site at: https://$PROJECT_DOMAIN"
        print_warning "Make sure '$PROJECT_DOMAIN' points to 127.0.0.1 in your hosts file."
    else
        print_info "Starting in direct port mode..."
        local COMPOSE_CMD=($(compose_files))
        "${COMPOSE_CMD[@]}" up -d --build
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
# The password is read from the container environment (MYSQL_PWD), so it never
# appears on a command line and is not altered by '$' in .env values.
mysql_shell() {
    check_env
    print_info "Opening MySQL shell..."
    local COMPOSE_CMD=($(compose_files))
    "${COMPOSE_CMD[@]}" exec database sh -c \
        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec "$(command -v mariadb || command -v mysql)" -uroot'
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
        # --pull fetches the latest base images (PHP security releases);
        # --no-cache alone would rebuild on top of the cached, outdated ones
        "${COMPOSE_CMD[@]}" build --pull --no-cache
        print_info "✓ Rebuild complete"
        echo ""
        start "$@"
    else
        print_info "Rebuild cancelled"
    fi
}

# Update the webserver image (e.g. after a PHP security release): pull the
# latest base image, rebuild, show the new PHP version, then recreate the
# webserver only. The database container is never touched.
update() {
    check_env
    local assume_yes=false
    if [ "$1" = "--yes" ] || [ "$1" = "-y" ]; then
        assume_yes=true
    fi

    local COMPOSE_CMD=($(compose_files))
    # 'config --images' lists every service image (webserver + database),
    # e.g. lamp-webserver:php83
    local image backup
    image=$("${COMPOSE_CMD[@]}" config --images | grep -E -- '-webserver(:|$)' | head -n 1)
    case "$image" in
        *:*) backup="$image-pre-update" ;;
        *)   backup="$image:pre-update" ;;
    esac
    local container="${COMPOSE_PROJECT_NAME}-webserver"

    print_header "Updating webserver: $COMPOSE_PROJECT_NAME"

    local current="not running"
    if docker ps --format '{{.Names}}' | grep -qx "$container"; then
        current=$(docker exec "$container" php -r 'echo PHP_VERSION;')
    fi

    # Keep the current image for a rollback
    if docker image inspect "$image" >/dev/null 2>&1; then
        docker tag "$image" "$backup"
        print_info "Current image saved as $backup"
    fi

    "${COMPOSE_CMD[@]}" build --pull webserver

    local new
    new=$(docker run --rm --entrypoint php "$image" -r 'echo PHP_VERSION;')
    print_info "PHP version: $current (running) -> $new (new image)"

    if [ "$assume_yes" != true ]; then
        read -p "Recreate the webserver with the new image? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Update cancelled: new image built, running container unchanged"
            return
        fi
    fi

    "${COMPOSE_CMD[@]}" up -d --no-deps webserver

    local running
    running=$(docker exec "$container" php -r 'echo PHP_VERSION;')
    if [ "$running" != "$new" ]; then
        print_error "Webserver runs PHP $running, expected $new"
        exit 1
    fi
    print_info "✓ Webserver now runs PHP $running"
    print_info "Rollback: docker tag $backup $image && ${COMPOSE_CMD[*]} up -d --no-deps webserver"
}

# Dump all databases to data/db-dumps/<project>-<date>.sql.gz.
# The dump is consistent while the site is running (--single-transaction),
# unlike a copy of the MySQL data directory. Keeps the DB_DUMP_KEEP most
# recent dumps (default 7).
dump() {
    check_env
    local dir="${DB_DUMP_DIR:-./data/db-dumps}"
    local keep="${DB_DUMP_KEEP:-7}"
    local file="$dir/${COMPOSE_PROJECT_NAME}-$(date -u +%Y-%m-%d_%H%M%S).sql.gz"
    local COMPOSE_CMD=($(compose_files))

    mkdir -p "$dir"
    chmod 700 "$dir"
    print_info "Dumping all databases to $file..."

    # Password read from the container environment, never on a command line
    if ( set -o pipefail
         "${COMPOSE_CMD[@]}" exec -T database sh -c '
             D=$(command -v mariadb-dump || command -v mysqldump)
             MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec "$D" -uroot --all-databases \
                 --single-transaction --quick --routines --events --triggers' \
             | gzip > "$file.tmp" ) \
       && gzip -dc "$file.tmp" | tail -n 1 | grep -q 'Dump completed'; then
        mv "$file.tmp" "$file"
        chmod 600 "$file"
        print_info "✓ Dump complete ($(du -h "$file" | cut -f1))"
    else
        rm -f "$file.tmp"
        print_error "Dump failed or incomplete"
        exit 1
    fi

    # Rotation: keep the $keep most recent dumps of this project
    ls -1t "$dir/${COMPOSE_PROJECT_NAME}"-*.sql.gz 2>/dev/null | tail -n +$((keep + 1)) \
        | while read -r old; do rm -f "$old"; done
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
        
        read -p "Also remove the database data in $(mysql_data_dir)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            wipe_mysql_data
            # 'run' recreated the project network: remove it again
            "${COMPOSE_CMD[@]}" down >/dev/null 2>&1 || true
            print_info "✓ Database data directory cleaned"
        fi
    else
        print_info "Clean cancelled"
    fi
}

# Clean MySQL data directory only
clean_db() {
    check_env
    print_header "Cleaning MySQL Data Directory"
    print_warning "This will remove ALL database data in $(mysql_data_dir)!"
    print_warning "Make sure to backup if you have important data (./lamp.sh dump)!"
    echo ""
    print_info "Use this if MySQL won't start due to 'data directory has files' error"
    echo ""
    read -p "Remove all MySQL data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stops the database container, then empties the directory
        wipe_mysql_data
        print_info "✓ Database data directory cleaned"

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
    echo -e "${BLUE}Environment:${NC} ${LAMPBOX_ENV:-development}"
    echo -e "${BLUE}PHP Version:${NC} $PHPVERSION"
    echo -e "${BLUE}Database:${NC} $DATABASE"
    echo ""

    # Effective phpMyAdmin rule (same defaults as the compose files)
    local pma_rule="$PHPMYADMIN_REQUIRE"
    if [ -z "$pma_rule" ]; then
        if [ "$LAMPBOX_ENV" = "production" ]; then
            pma_rule="all denied"
        else
            pma_rule="all granted"
        fi
    fi
    echo -e "${BLUE}phpMyAdmin access:${NC} Require $pma_rule"
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
    dump)
        dump
        ;;
    rebuild)
        rebuild "$2"
        ;;
    update)
        update "$2"
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
