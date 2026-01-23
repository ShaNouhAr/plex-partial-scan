#!/bin/bash

# Script pour lister les bibliothèques Plex avec leurs IDs

CONFIG_FILE="./plex-scan.conf"

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      📚 Bibliothèques Plex             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Charger config ou demander les infos
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
    echo -e "${GREEN}✓ Config chargée depuis $CONFIG_FILE${NC}"
else
    echo -e "${YELLOW}Config non trouvée, entrez les informations :${NC}"
    read -p "IP Plex : " PLEX_IP
    read -p "Port Plex (32400) : " PLEX_PORT
    PLEX_PORT=${PLEX_PORT:-32400}
    read -p "Token Plex : " PLEX_TOKEN
fi

echo ""
echo -e "${YELLOW}Récupération des bibliothèques...${NC}"
echo ""

# Appel API Plex
RESPONSE=$(curl -s "http://${PLEX_IP}:${PLEX_PORT}/library/sections?X-Plex-Token=${PLEX_TOKEN}")

if [ -z "$RESPONSE" ]; then
    echo "❌ Erreur : Impossible de contacter Plex"
    exit 1
fi

# Parser le XML et afficher les résultats
echo -e "${BLUE}┌──────┬──────────────────────────┬────────────────┐${NC}"
echo -e "${BLUE}│  ID  │ Nom                      │ Type           │${NC}"
echo -e "${BLUE}├──────┼──────────────────────────┼────────────────┤${NC}"

echo "$RESPONSE" | grep -oP '<Directory[^>]*>' | while read -r line; do
    KEY=$(echo "$line" | grep -oP 'key="\K[^"]+')
    TITLE=$(echo "$line" | grep -oP 'title="\K[^"]+')
    TYPE=$(echo "$line" | grep -oP 'type="\K[^"]+')
    
    # Traduire le type
    case "$TYPE" in
        "movie") TYPE_FR="🎬 Films" ;;
        "show")  TYPE_FR="📺 Séries TV" ;;
        "artist") TYPE_FR="🎵 Musique" ;;
        "photo") TYPE_FR="📷 Photos" ;;
        *) TYPE_FR="❓ $TYPE" ;;
    esac
    
    printf "${BLUE}│${NC}  %-3s ${BLUE}│${NC} %-24s ${BLUE}│${NC} %-14s ${BLUE}│${NC}\n" "$KEY" "$TITLE" "$TYPE_FR"
done

echo -e "${BLUE}└──────┴──────────────────────────┴────────────────┘${NC}"
echo ""

# Afficher les chemins de chaque bibliothèque
echo -e "${YELLOW}📂 Chemins des bibliothèques :${NC}"
echo ""

echo "$RESPONSE" | grep -oP '<Directory[^>]*>' | while read -r line; do
    KEY=$(echo "$line" | grep -oP 'key="\K[^"]+')
    TITLE=$(echo "$line" | grep -oP 'title="\K[^"]+')
    
    # Récupérer les détails de la bibliothèque
    LIB_RESPONSE=$(curl -s "http://${PLEX_IP}:${PLEX_PORT}/library/sections/${KEY}?X-Plex-Token=${PLEX_TOKEN}")
    PATHS=$(echo "$LIB_RESPONSE" | grep -oP '<Location[^>]*path="\K[^"]+')
    
    echo -e "${GREEN}[$KEY] $TITLE${NC}"
    echo "$PATHS" | while read -r p; do
        echo "    → $p"
    done
    echo ""
done

echo -e "${GREEN}💡 Le chemin dans WATCHDIRS doit correspondre EXACTEMENT au chemin Plex ci-dessus${NC}"
c