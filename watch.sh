#!/bin/sh

CONFIG_FILE="/config/plex-scan.conf"
SNAPSHOT_DIR="/data/snapshots"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config introuvable : $CONFIG_FILE"
  exit 1
fi

. "$CONFIG_FILE"

# Créer le dossier snapshots s'il n'existe pas
mkdir -p "$SNAPSHOT_DIR"

echo "▶️ Démarrage surveillance multi-watchdir"
echo "📸 Snapshots persistants dans : $SNAPSHOT_DIR"
echo "$WATCHDIRS"

scan_plex() {
  lib_id="$1"
  local_path="$2"
  watch_base="$3"
  plex_base="$4"
  
  # Convertir le chemin local en chemin Plex
  plex_path=$(echo "$local_path" | sed "s|^${watch_base}|${plex_base}|")
  
  # Encoder le chemin pour l'URL
  encoded_path=$(printf '%s' "$plex_path" | sed 's/ /%20/g; s/\[/%5B/g; s/\]/%5D/g')
  
  echo "→ Scan Plex (lib $lib_id)"
  echo "  Local : $local_path"
  echo "  Plex  : $plex_path"
  
  response=$(curl -s -w "\n%{http_code}" \
    "http://${PLEX_IP}:${PLEX_PORT}/library/sections/${lib_id}/refresh?path=${encoded_path}&X-Plex-Token=${PLEX_TOKEN}")
  
  http_code=$(echo "$response" | tail -n1)
  
  if [ "$http_code" = "200" ]; then
    echo "  ✓ Scan lancé avec succès"
  else
    echo "  ❌ Erreur HTTP $http_code"
  fi
}

for entry in $WATCHDIRS; do
  WATCH_PATH=$(echo "$entry" | cut -d'|' -f1)
  LIB_ID=$(echo "$entry" | cut -d'|' -f2)

  STATE_FILE="${SNAPSHOT_DIR}/state_$(echo "$WATCH_PATH" | tr '/' '_').txt"

  (
    echo "👀 Surveillance de $WATCH_PATH"
    if [ ! -f "$STATE_FILE" ]; then
      find "$WATCH_PATH" -type f 2>/dev/null | sort > "$STATE_FILE"
    fi

    while true; do
      CURRENT_STATE=$(mktemp)
      find "$WATCH_PATH" -type f 2>/dev/null | sort > "$CURRENT_STATE"

      NEW_FILES=$(comm -13 "$STATE_FILE" "$CURRENT_STATE")

      if [ -n "$NEW_FILES" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Nouveaux fichiers dans $WATCH_PATH"

        echo "$NEW_FILES" \
          | while read -r file; do
              [ -n "$file" ] && echo "$(dirname "$file")"
            done \
          | sort -u \
          | while read -r dir; do
              scan_plex "$LIB_ID" "$dir"
            done
      fi

      mv "$CURRENT_STATE" "$STATE_FILE"
      sleep "$INTERVAL"
    done
  ) &
done

wait
