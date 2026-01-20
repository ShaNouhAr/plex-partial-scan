#!/bin/sh

CONFIG_FILE="/config/plex-scan.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config introuvable : $CONFIG_FILE"
  exit 1
fi

. "$CONFIG_FILE"

echo "▶️ Démarrage surveillance multi-watchdir"
echo "$WATCHDIRS"

scan_plex() {
  lib_id="$1"
  path="$2"
  echo "→ Scan Plex (lib $lib_id) sur : $path"
  curl -s \
"http://${PLEX_IP}:${PLEX_PORT}/library/sections/${lib_id}/refresh?path=${path}&X-Plex-Token=${PLEX_TOKEN}" \
  > /dev/null
}

for entry in $WATCHDIRS; do
  WATCH_PATH=$(echo "$entry" | cut -d'|' -f1)
  LIB_ID=$(echo "$entry" | cut -d'|' -f2)

  STATE_FILE="/tmp/state_$(echo "$WATCH_PATH" | tr '/' '_').txt"

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
