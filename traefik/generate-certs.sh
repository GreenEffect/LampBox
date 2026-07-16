#!/bin/bash

# ==============================================================================
# LampBox - Shared TLS certificate generator for Traefik
# ==============================================================================
# Generates ONE self-signed certificate covering every *.local domain, used by
# Traefik as its default certificate for all LampBox projects.
#
# Usage:
#   ./traefik/generate-certs.sh
#
# For browser-trusted certificates, prefer mkcert (https://github.com/FiloSottile/mkcert):
#   mkcert -install
#   mkcert -cert-file traefik/certs/cert.pem -key-file traefik/certs/cert-key.pem \
#          "*.local" localhost 127.0.0.1
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Work from the traefik/ directory and use RELATIVE paths for openssl.
# Absolute MSYS paths (/c/Users/...) break the native Windows openssl when
# MSYS_NO_PATHCONV=1 is set; relative paths resolve against the current dir.
cd "$(dirname "${BASH_SOURCE[0]}")"
CERT_DIR="certs"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/cert-key.pem"

mkdir -p "$CERT_DIR"

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    print_error "openssl is not installed!"
    print_info "Please install openssl first:"
    print_info "  Ubuntu/Debian: sudo apt-get install openssl"
    print_info "  MacOS: brew install openssl"
    exit 1
fi

print_info "Generating shared self-signed certificate for *.local ..."
rm -f "$CERT_FILE" "$KEY_FILE"

# MSYS_NO_PATHCONV=1 prevents Git Bash from mangling the -subj/-addext paths
MSYS_NO_PATHCONV=1 openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=FR/ST=State/L=City/O=LampBox/CN=*.local" \
    -addext "subjectAltName=DNS:*.local,DNS:localhost,IP:127.0.0.1"

# Validate certificate and key match
CERT_MODULUS=$(openssl x509 -noout -modulus -in "$CERT_FILE" | openssl md5)
KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_FILE" | openssl md5)
if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    print_error "The generated certificate and key do not match."
    rm -f "$CERT_FILE" "$KEY_FILE"
    exit 1
fi

chmod 644 "$CERT_FILE"
chmod 600 "$KEY_FILE"

print_info "✓ Shared certificate generated successfully!"
echo ""
print_info "Certificate location:"
echo "  - $CERT_FILE"
echo "  - $KEY_FILE"
echo ""
print_warning "This is a self-signed certificate. Your browser will show a security warning."
print_info "To avoid warnings, use mkcert (see the header of this script)."
echo ""
print_warning "Note: *.local covers single-level domains (e.g. project1.local)."
print_warning "Sub-subdomains such as api.project1.local need their own certificate."
