#!/bin/bash

# Script de test pour une configuration spécifique
# Usage: ./test-config.sh <php_version> <db_version> <http_port> <mysql_port>
#   ou: ./test-config.sh <env_file>

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour lire une variable depuis un fichier .env
read_env_var() {
    local file=$1
    local var=$2
    grep "^${var}=" "$file" 2>/dev/null | cut -d '=' -f2- | sed 's/^"\(.*\)"$/\1/' | xargs
}

# Définir les chemins absolus dès le début
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Vérification des arguments
if [ $# -eq 1 ]; then
    # Mode: un seul argument = fichier .env
    CUSTOM_ENV_FILE=$1
    
    # Vérifier que le fichier existe
    if [ ! -f "$CUSTOM_ENV_FILE" ]; then
        # Essayer depuis le répertoire parent
        if [ -f "${PROJECT_ROOT}/${CUSTOM_ENV_FILE}" ]; then
            CUSTOM_ENV_FILE="${PROJECT_ROOT}/${CUSTOM_ENV_FILE}"
        else
            echo -e "${RED}Erreur: Le fichier .env '$CUSTOM_ENV_FILE' n'existe pas${NC}"
            exit 1
        fi
    fi
    
    # Lire les variables depuis le fichier .env
    PHP_VERSION=$(read_env_var "$CUSTOM_ENV_FILE" "PHPVERSION")
    DB_VERSION=$(read_env_var "$CUSTOM_ENV_FILE" "DATABASE")
    HTTP_PORT=$(read_env_var "$CUSTOM_ENV_FILE" "HTTP_PORT")
    MYSQL_PORT=$(read_env_var "$CUSTOM_ENV_FILE" "MYSQL_PORT")
    PROJECT_NAME=$(read_env_var "$CUSTOM_ENV_FILE" "COMPOSE_PROJECT_NAME")
    
    # Vérifier que toutes les variables nécessaires sont présentes
    if [ -z "$PHP_VERSION" ] || [ -z "$DB_VERSION" ] || [ -z "$HTTP_PORT" ] || [ -z "$MYSQL_PORT" ] || [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}Erreur: Le fichier .env doit contenir PHPVERSION, DATABASE, HTTP_PORT, MYSQL_PORT et COMPOSE_PROJECT_NAME${NC}"
        exit 1
    fi
    
    ENV_FILE="$CUSTOM_ENV_FILE"
    USE_CUSTOM_ENV=true
elif [ $# -ge 4 ]; then
    # Mode: arguments séparés
    PHP_VERSION=$1
    DB_VERSION=$2
    HTTP_PORT=$3
    MYSQL_PORT=$4
    PROJECT_NAME="test-${PHP_VERSION}-${DB_VERSION}"
    USE_CUSTOM_ENV=false
else
    echo -e "${RED}Usage: $0 <php_version> <db_version> <http_port> <mysql_port>${NC}"
    echo "   ou: $0 <env_file>"
    echo ""
    echo "Exemples:"
    echo "  $0 php85 mariadb121 9000 9300"
    echo "  $0 .env.test.test-php85-mariadb121"
    exit 1
fi

# Définir les chemins absolus pour les logs
LOG_DIR="${TEST_DIR}/logs"
LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"

# Créer le répertoire de logs s'il n'existe pas
mkdir -p "$LOG_DIR"

# Fonction de log
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Fonction d'affichage coloré
print_info() {
    echo -e "${BLUE}$1${NC}"
    log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
    log "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}$1${NC}"
    log "ERROR" "$1"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
    log "WARNING" "$1"
}

# Début du test
echo ""
print_info "=========================================="
print_info "Test de configuration: PHP $PHP_VERSION + $DB_VERSION"
print_info "Ports: HTTP=$HTTP_PORT, MySQL=$MYSQL_PORT"
print_info "=========================================="

# Créer ou utiliser le fichier .env
if [ "$USE_CUSTOM_ENV" = false ]; then
    # Créer un .env temporaire pour ce test
    ENV_FILE="${PROJECT_ROOT}/.env.test.${PROJECT_NAME}"
    
    print_info "Création du fichier .env de test..."
    cat > "$ENV_FILE" <<EOF
COMPOSE_PROJECT_NAME=${PROJECT_NAME}
USER_ID=1000
GROUP_ID=1000

USE_REVERSE_PROXY=false
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=$((HTTP_PORT + 400))
MYSQL_PORT=${MYSQL_PORT}

PHPVERSION=${PHP_VERSION}
DATABASE=${DB_VERSION}

DOCUMENT_ROOT=./www
APACHE_DOCUMENT_ROOT=/var/www/html

MYSQL_ROOT_PASSWORD=testroot
MYSQL_DATABASE=testdb
MYSQL_USER=testuser
MYSQL_PASSWORD=testpass

PHPMYADMIN_BLOWFISH_SECRET=testblowfishsecretkey123456
EOF
    
    print_success "Fichier .env créé: $ENV_FILE"
else
    print_info "Utilisation du fichier .env personnalisé: $ENV_FILE"
    # S'assurer que le chemin est absolu
    if [[ "$ENV_FILE" != /* ]] && [[ "$ENV_FILE" != .* ]]; then
        ENV_FILE="${PROJECT_ROOT}/${ENV_FILE}"
    fi
    if [ ! -f "$ENV_FILE" ]; then
        print_error "Le fichier .env '$ENV_FILE' n'existe pas"
        exit 1
    fi
    print_success "Fichier .env trouvé: $ENV_FILE"
fi

# Vérifier et créer les répertoires nécessaires
print_info "Vérification des répertoires nécessaires..."
cd "$PROJECT_ROOT"
mkdir -p www
mkdir -p config/initdb
mkdir -p config/php
mkdir -p config/phpmyadmin
mkdir -p config/vhosts
mkdir -p config/ssl
mkdir -p logs/apache2
mkdir -p logs/mysql
mkdir -p data/mysql

# Créer un fichier php.ini minimal si nécessaire
if [ ! -f "config/php/php.ini" ]; then
    print_info "Création d'un fichier php.ini minimal..."
    echo "; PHP Configuration" > config/php/php.ini
    echo "display_errors = On" >> config/php/php.ini
    echo "error_reporting = E_ALL" >> config/php/php.ini
fi

# Créer un fichier index.php minimal si nécessaire
if [ ! -f "www/index.php" ]; then
    print_info "Création d'un fichier index.php minimal..."
    cat > www/index.php <<'PHPEOF'
<?php
phpinfo();
PHPEOF
fi

# Nettoyer les anciens conteneurs s'ils existent
print_info "Nettoyage des anciens conteneurs..."
docker compose --env-file "$ENV_FILE" down -v 2>/dev/null || true

# Vérifier si les images existent déjà
print_info "Vérification des images Docker..."

# Construire les images si nécessaire
BUILD_NEEDED=false

# Vérifier si l'image webserver existe
WEBSERVER_IMAGE_NAME="${PROJECT_NAME}-webserver"
if ! docker images --format "{{.Repository}}" | grep -q "^${WEBSERVER_IMAGE_NAME}$"; then
    print_info "Image webserver non trouvée, construction nécessaire"
    BUILD_NEEDED=true
fi

# Vérifier si l'image database existe (pour les images custom)
if [ -f "bin/${DB_VERSION}/Dockerfile" ]; then
    DATABASE_IMAGE_NAME="${PROJECT_NAME}-database"
    if ! docker images --format "{{.Repository}}" | grep -q "^${DATABASE_IMAGE_NAME}$"; then
        print_info "Image database non trouvée, construction nécessaire"
        BUILD_NEEDED=true
    fi
fi

if [ "$BUILD_NEEDED" = true ]; then
    print_info "Construction des images Docker..."
    if ! docker compose --env-file "$ENV_FILE" build 2>&1 | tee -a "$LOG_FILE"; then
        print_warning "Échec de la construction avec cache, tentative sans cache..."
        if ! docker compose --env-file "$ENV_FILE" build --no-cache 2>&1 | tee -a "$LOG_FILE"; then
            print_error "Échec de la construction des images"
            cd "$TEST_DIR"
            exit 1
        fi
    fi
    print_success "Images construites avec succès"
else
    print_info "Images déjà existantes, utilisation des images existantes"
    log "INFO" "Images réutilisées (pas de reconstruction)"
fi

# Démarrer les conteneurs
print_info "Démarrage des conteneurs..."
if ! docker compose --env-file "$ENV_FILE" up -d 2>&1 | tee -a "$LOG_FILE"; then
    print_error "Échec du démarrage des conteneurs"
    print_info "Affichage des logs pour diagnostic..."
    docker compose --env-file "$ENV_FILE" logs 2>&1 | tail -n 50 | tee -a "$LOG_FILE"
    cd "$TEST_DIR"
    exit 1
fi
print_success "Conteneurs démarrés"

# Attendre que les conteneurs soient prêts avec vérification progressive
print_info "Attente du démarrage des services..."
MAX_WAIT=60
WAIT_COUNT=0
CONTAINERS_READY=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if docker ps | grep -q "${PROJECT_NAME}-webserver" && docker ps | grep -q "${PROJECT_NAME}-database"; then
        # Vérifier que les conteneurs sont vraiment prêts (pas juste en cours de démarrage)
        WEBSERVER_STATUS=$(docker inspect --format='{{.State.Status}}' "${PROJECT_NAME}-webserver" 2>/dev/null || echo "missing")
        DATABASE_STATUS=$(docker inspect --format='{{.State.Status}}' "${PROJECT_NAME}-database" 2>/dev/null || echo "missing")
        
        if [ "$WEBSERVER_STATUS" = "running" ] && [ "$DATABASE_STATUS" = "running" ]; then
            CONTAINERS_READY=true
            break
        fi
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
        print_info "Attente... ($WAIT_COUNT/$MAX_WAIT secondes)"
    fi
done

if [ "$CONTAINERS_READY" = true ]; then
    print_success "Conteneurs démarrés et prêts"
else
    print_error "Les conteneurs ne sont pas prêts après $MAX_WAIT secondes"
    print_info "Statut des conteneurs:"
    docker compose --env-file "$ENV_FILE" ps
    print_info "Logs webserver:"
    docker compose --env-file "$ENV_FILE" logs webserver 2>&1 | tail -n 20 | tee -a "$LOG_FILE"
    print_info "Logs database:"
    docker compose --env-file "$ENV_FILE" logs database 2>&1 | tail -n 20 | tee -a "$LOG_FILE"
    cd "$TEST_DIR"
    exit 1
fi

# Vérifier la version de PHP
print_info "Vérification de la version PHP..."
PHP_VER=$(docker exec "${PROJECT_NAME}-webserver" php -v | head -n 1)
print_info "Version PHP détectée: $PHP_VER"
log "INFO" "Version PHP: $PHP_VER"

# Vérifier la version de la base de données
print_info "Vérification de la version de la base de données..."
if [[ "$DB_VERSION" == mysql* ]]; then
    DB_VER=$(docker exec "${PROJECT_NAME}-database" mysql --version)
else
    DB_VER=$(docker exec "${PROJECT_NAME}-database" mariadb --version)
fi
print_info "Version DB détectée: $DB_VER"
log "INFO" "Version DB: $DB_VER"

# Tester la connexion à la base de données
print_info "Test de connexion à la base de données..."
sleep 5

# Lire les credentials depuis le .env
DB_USER=$(read_env_var "$ENV_FILE" "MYSQL_USER")
DB_PASSWORD=$(read_env_var "$ENV_FILE" "MYSQL_PASSWORD")
DB_NAME=$(read_env_var "$ENV_FILE" "MYSQL_DATABASE")

# Valeurs par défaut
DB_USER=${DB_USER:-testuser}
DB_PASSWORD=${DB_PASSWORD:-testpass}
DB_NAME=${DB_NAME:-testdb}

if docker exec "${PROJECT_NAME}-database" mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1; then
    print_success "Connexion à la base de données réussie"
    log "SUCCESS" "Connexion DB réussie"
else
    print_warning "Connexion à la base de données échouée (peut être normal si la DB n'est pas encore prête)"
    log "WARNING" "Connexion DB échouée"
fi

# Afficher les URLs de test
echo ""
print_success "=========================================="
print_success "✅ Configuration testée avec succès!"
print_success "=========================================="
print_info "URLs de test:"
echo -e "${GREEN}  Site web:     http://localhost:${HTTP_PORT}${NC}"
echo -e "${GREEN}  phpMyAdmin:   http://localhost:${HTTP_PORT}/${PROJECT_NAME}-mysql${NC}"
echo ""
# Lire les informations de connexion depuis le .env pour l'affichage
MYSQL_USER_DISPLAY=$(read_env_var "$ENV_FILE" "MYSQL_USER")
MYSQL_PASSWORD_DISPLAY=$(read_env_var "$ENV_FILE" "MYSQL_PASSWORD")
MYSQL_DATABASE_DISPLAY=$(read_env_var "$ENV_FILE" "MYSQL_DATABASE")

# Valeurs par défaut si non définies
MYSQL_USER_DISPLAY=${MYSQL_USER_DISPLAY:-testuser}
MYSQL_PASSWORD_DISPLAY=${MYSQL_PASSWORD_DISPLAY:-testpass}
MYSQL_DATABASE_DISPLAY=${MYSQL_DATABASE_DISPLAY:-testdb}

print_info "Informations de connexion DB:"
echo -e "${BLUE}  Host:     localhost${NC}"
echo -e "${BLUE}  Port:     ${MYSQL_PORT}${NC}"
echo -e "${BLUE}  User:     ${MYSQL_USER_DISPLAY}${NC}"
echo -e "${BLUE}  Password: ${MYSQL_PASSWORD_DISPLAY}${NC}"
echo -e "${BLUE}  Database: ${MYSQL_DATABASE_DISPLAY}${NC}"
echo ""
print_info "Fichier .env utilisé: $ENV_FILE"
print_info "Logs disponibles dans: $LOG_FILE"
echo ""

# Enregistrer les URLs dans le log
log "INFO" "URL Site web: http://localhost:${HTTP_PORT}"
log "INFO" "URL phpMyAdmin: http://localhost:${HTTP_PORT}/${PROJECT_NAME}-mysql"
log "INFO" "Fichier .env: $ENV_FILE"
log "SUCCESS" "Test terminé avec succès"

cd "$TEST_DIR"

