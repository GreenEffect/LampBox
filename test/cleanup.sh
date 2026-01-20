#!/bin/bash

# Script de nettoyage pour supprimer tous les conteneurs de test

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}Nettoyage des conteneurs de test...${NC}"
echo ""

# Trouver tous les conteneurs de test
TEST_CONTAINERS=$(docker ps -a --filter "name=test-" --format "{{.Names}}" 2>/dev/null || true)

if [ -z "$TEST_CONTAINERS" ]; then
    echo -e "${GREEN}Aucun conteneur de test trouvé${NC}"
else
    echo -e "${YELLOW}Conteneurs trouvés:${NC}"
    echo "$TEST_CONTAINERS"
    echo ""
    
    read -p "Voulez-vous supprimer ces conteneurs? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Arrêt et suppression des conteneurs...${NC}"
        
        # Arrêter et supprimer les conteneurs
        for container in $TEST_CONTAINERS; do
            echo "  Suppression de $container..."
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        done
        
        # Supprimer les images Docker de test associées
        echo -e "${BLUE}Recherche des images Docker de test...${NC}"
        TEST_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^test-" 2>/dev/null || true)
        if [ -n "$TEST_IMAGES" ]; then
            echo -e "${YELLOW}Images trouvées:${NC}"
            echo "$TEST_IMAGES"
            echo ""
            read -p "Voulez-vous supprimer ces images? (y/N) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                IMAGE_COUNT=0
                for image in $TEST_IMAGES; do
                    echo "  Suppression de $image..."
                    if docker rmi -f "$image" 2>/dev/null || docker rmi "$image" 2>/dev/null; then
                        IMAGE_COUNT=$((IMAGE_COUNT + 1))
                    else
                        echo -e "${YELLOW}    (Image peut être utilisée par un conteneur ou en cours de construction)${NC}"
                    fi
                done
                if [ $IMAGE_COUNT -gt 0 ]; then
                    echo -e "${GREEN}  ✅ $IMAGE_COUNT image(s) supprimée(s)${NC}"
                fi
            fi
        else
            echo -e "${BLUE}Aucune image de test trouvée${NC}"
        fi
        
        # Supprimer les fichiers .env de test
        echo -e "${BLUE}Suppression des fichiers .env de test...${NC}"
        ENV_FILES_COUNT=0
        
        # Utiliser une boucle for avec glob pour être plus robuste
        if [ -d "$PROJECT_ROOT" ]; then
            cd "$PROJECT_ROOT"
            
            # Méthode 1: Utiliser find (plus fiable)
            ENV_FILES_FIND=$(find . -maxdepth 1 -name ".env.test.*" -type f 2>/dev/null || true)
            if [ -n "$ENV_FILES_FIND" ]; then
                for env_file in $ENV_FILES_FIND; do
                    if [ -f "$env_file" ]; then
                        echo "  Suppression de $(basename "$env_file")..."
                        if rm -f "$env_file"; then
                            ENV_FILES_COUNT=$((ENV_FILES_COUNT + 1))
                        else
                            echo -e "${RED}  Erreur lors de la suppression de $env_file${NC}"
                        fi
                    fi
                done
            fi
            
            # Méthode 2: Utiliser ls si find ne fonctionne pas
            if [ $ENV_FILES_COUNT -eq 0 ]; then
                ENV_FILES_LS=$(ls -1 .env.test.* 2>/dev/null || true)
                if [ -n "$ENV_FILES_LS" ]; then
                    for env_file in $ENV_FILES_LS; do
                        if [ -f "$env_file" ]; then
                            echo "  Suppression de $env_file..."
                            if rm -f "$env_file"; then
                                ENV_FILES_COUNT=$((ENV_FILES_COUNT + 1))
                            fi
                        fi
                    done
                fi
            fi
            
            cd "$SCRIPT_DIR"
            
            if [ $ENV_FILES_COUNT -eq 0 ]; then
                echo -e "${YELLOW}Aucun fichier .env.test.* trouvé dans $PROJECT_ROOT${NC}"
            else
                echo -e "${GREEN}  ✅ $ENV_FILES_COUNT fichier(s) .env supprimé(s)${NC}"
            fi
        else
            echo -e "${RED}  Erreur: Répertoire parent non trouvé: $PROJECT_ROOT${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✅ Nettoyage terminé${NC}"
    else
        echo -e "${YELLOW}Nettoyage annulé${NC}"
    fi
fi

# Option pour supprimer les fichiers .env de test (même s'il n'y a pas de conteneurs)
echo ""
read -p "Voulez-vous supprimer les fichiers .env de test? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Recherche des fichiers .env de test...${NC}"
    ENV_FILES_COUNT=0
    
    if [ -d "$PROJECT_ROOT" ]; then
        cd "$PROJECT_ROOT"
        
        # Méthode 1: Utiliser find (plus fiable)
        ENV_FILES_FIND=$(find . -maxdepth 1 -name ".env.test.*" -type f 2>/dev/null || true)
        if [ -n "$ENV_FILES_FIND" ]; then
            for env_file in $ENV_FILES_FIND; do
                if [ -f "$env_file" ]; then
                    echo "  Suppression de $(basename "$env_file")..."
                    if rm -f "$env_file"; then
                        ENV_FILES_COUNT=$((ENV_FILES_COUNT + 1))
                    else
                        echo -e "${RED}  Erreur lors de la suppression de $env_file${NC}"
                    fi
                fi
            done
        fi
        
        # Méthode 2: Utiliser ls si find ne fonctionne pas
        if [ $ENV_FILES_COUNT -eq 0 ]; then
            ENV_FILES_LS=$(ls -1 .env.test.* 2>/dev/null || true)
            if [ -n "$ENV_FILES_LS" ]; then
                for env_file in $ENV_FILES_LS; do
                    if [ -f "$env_file" ]; then
                        echo "  Suppression de $env_file..."
                        if rm -f "$env_file"; then
                            ENV_FILES_COUNT=$((ENV_FILES_COUNT + 1))
                        fi
                    fi
                done
            fi
        fi
        
        # Méthode 3: Boucle for avec glob (dernier recours)
        if [ $ENV_FILES_COUNT -eq 0 ]; then
            shopt -s nullglob  # Ne pas retourner le pattern si aucun fichier
            for env_file in .env.test.*; do
                if [ -f "$env_file" ]; then
                    echo "  Suppression de $env_file..."
                    if rm -f "$env_file"; then
                        ENV_FILES_COUNT=$((ENV_FILES_COUNT + 1))
                    fi
                fi
            done
            shopt -u nullglob
        fi
        
        cd "$SCRIPT_DIR"
        
        if [ $ENV_FILES_COUNT -eq 0 ]; then
            echo -e "${BLUE}Aucun fichier .env.test.* trouvé dans $PROJECT_ROOT${NC}"
        else
            echo -e "${GREEN}✅ $ENV_FILES_COUNT fichier(s) .env supprimé(s)${NC}"
        fi
    else
        echo -e "${RED}Erreur: Répertoire parent non trouvé: $PROJECT_ROOT${NC}"
    fi
fi

# Option pour supprimer les images Docker de test (même s'il n'y a pas de conteneurs)
echo ""
read -p "Voulez-vous supprimer les images Docker de test? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Recherche des images Docker de test...${NC}"
    TEST_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^test-" 2>/dev/null || true)
    if [ -n "$TEST_IMAGES" ]; then
        echo -e "${YELLOW}Images trouvées:${NC}"
        echo "$TEST_IMAGES"
        echo ""
        IMAGE_COUNT=0
        for image in $TEST_IMAGES; do
            echo "  Suppression de $image..."
            # Essayer d'abord avec -f (force), puis sans si ça échoue
            if docker rmi -f "$image" 2>/dev/null || docker rmi "$image" 2>/dev/null; then
                IMAGE_COUNT=$((IMAGE_COUNT + 1))
            else
                echo -e "${YELLOW}    (Image peut être utilisée par un conteneur ou en cours de construction)${NC}"
                # Essayer de supprimer les images en cours de construction (dangling)
                docker image prune -f --filter "dangling=true" 2>/dev/null || true
            fi
        done
        if [ $IMAGE_COUNT -gt 0 ]; then
            echo -e "${GREEN}✅ $IMAGE_COUNT image(s) supprimée(s)${NC}"
        else
            echo -e "${YELLOW}Aucune image supprimée (peut-être en cours d'utilisation)${NC}"
        fi
    else
        echo -e "${BLUE}Aucune image de test trouvée${NC}"
    fi
fi

# Option pour supprimer les logs
echo ""
read -p "Voulez-vous supprimer les logs de test? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "logs" ] && [ "$(ls -A logs 2>/dev/null)" ]; then
        rm -f logs/*.log
        echo -e "${GREEN}✅ Logs supprimés${NC}"
    else
        echo -e "${BLUE}Aucun log à supprimer${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Terminé!${NC}"

