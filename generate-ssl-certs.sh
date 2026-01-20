#!/bin/bash

# ==============================================================================
# SSL Certificate Generator for Docker LAMP Stack
# ==============================================================================
# This script generates self-signed SSL certificates for local development
# 
# Usage:
#   ./generate-ssl-certs.sh [domain]
#
# If no domain is provided, it uses PROJECT_DOMAIN from .env file
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    print_info "Please copy sample.env to .env and configure it first."
    exit 1
fi

# Load environment variables
source .env

# Get domain from argument or .env
DOMAIN=${1:-$PROJECT_DOMAIN}

if [ -z "$DOMAIN" ]; then
    print_error "No domain specified!"
    print_info "Usage: $0 [domain]"
    print_info "Or set PROJECT_DOMAIN in your .env file"
    exit 1
fi

# Create SSL directories if they don't exist
SSL_DIR="./config/nginx/ssl"
APACHE_SSL_DIR="./config/ssl"

mkdir -p "$SSL_DIR"
mkdir -p "$APACHE_SSL_DIR"

print_info "Generating SSL certificates for domain: $DOMAIN"

# Certificate files
CERT_FILE="$SSL_DIR/cert.pem"
KEY_FILE="$SSL_DIR/cert-key.pem"

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    print_error "openssl is not installed!"
    print_info "Please install openssl first:"
    print_info "  Ubuntu/Debian: sudo apt-get install openssl"
    print_info "  MacOS: brew install openssl"
    exit 1
fi

# Generate self-signed certificate
print_info "Generating self-signed certificate..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=FR/ST=State/L=City/O=Organization/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN,DNS:localhost,IP:127.0.0.1" \
    2>/dev/null

# Set proper permissions
chmod 644 "$CERT_FILE"
chmod 600 "$KEY_FILE"

# Copy certificates to Apache SSL directory for direct HTTPS access
cp "$CERT_FILE" "$APACHE_SSL_DIR/"
cp "$KEY_FILE" "$APACHE_SSL_DIR/"

print_info "✓ SSL certificates generated successfully!"
echo ""
print_info "Certificate location:"
echo "  - Nginx:  $CERT_FILE"
echo "  - Apache: $APACHE_SSL_DIR/cert.pem"
echo ""
print_warning "These are self-signed certificates. Your browser will show a security warning."
print_info "To avoid warnings, you can:"
echo "  1. Accept the certificate in your browser"
echo "  2. Or use mkcert for trusted local certificates:"
echo "     https://github.com/FiloSottile/mkcert"
echo ""
print_info "Don't forget to add this line to your /etc/hosts file:"
echo "  127.0.0.1    $DOMAIN"
