#!/bin/sh

CONFIG_FILE="/config/plex-scan.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config introuvable : $CONFIG_FILE"
  exit 1
fi

. "$CONFIG_FILE"

FIND_TIMEOUT=${FIND_TIMEOUT:-60}

echo "▶️ Démarrage surveillance multi-watchdir (polling, compatible rclone)"
echo "$WATCHDIRS"

snapshot_files() {
  watch_path="$1"
  output_file="$2"
  unsorted_file=$(mktemp)

  if [ ! -d "$watch_path" ]; then
    echo "⚠️  Dossier inaccessible, attente du retour du montage : $watch_path"
    rm -f "$unsorted_file"
    return 1
  fi

  if ! timeout "$FIND_TIMEOUT" find "$watch_path" -type f > "$unsorted_file" 2>/dev/null; then
    echo "⚠️  Lecture impossible ou trop longue, état conservé : $watch_path"
    rm -f "$unsorted_file"
    return 1
  fi

  sort "$unsorted_file" > "$output_file"
  rm -f "$unsorted_file"
  return 0
}

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
  PLEX_BASE=$(echo "$entry" | cut -d'|' -f4)

  (
    echo "👀 Surveillance de $WATCH_PATH"
    PREV=$(mktemp)

    until snapshot_files "$WATCH_PATH" "$PREV"; do
      sleep "$INTERVAL"
    done

    while true; do
      CURR=$(mktemp)

      if ! snapshot_files "$WATCH_PATH" "$CURR"; then
        rm -f "$CURR"
        sleep "$INTERVAL"
        continue
      fi

      NEW_FILES=$(comm -13 "$PREV" "$CURR")

      if [ -n "$NEW_FILES" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Nouveaux fichiers dans $WATCH_PATH"
        echo "$NEW_FILES" \
          | while read -r file; do
              [ -n "$file" ] && echo "$(dirname "$file")"
            done \
          | sort -u \
          | while read -r dir; do
              scan_plex "$LIB_ID" "$dir" "$WATCH_PATH" "$PLEX_BASE"
            done
      fi

      mv "$CURR" "$PREV"
      sleep "$INTERVAL"
    done
  ) &
done

wait
