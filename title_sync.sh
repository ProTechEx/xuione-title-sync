#!/bin/bash

# XUI-One Title Sync Script

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$BASE_DIR/config.env" ]; then
  echo "config.env not found in $BASE_DIR. Please run installer.sh first."
  exit 1
fi

# shellcheck source=/dev/null
. "$BASE_DIR/config.env"

LOGFILE="$BASE_DIR/sync.log"
PROVIDER_DEBUG="$BASE_DIR/provider.json"

# Fetch provider JSON
PROVIDER_JSON="$(curl -s "${PROVIDER_URL}?username=${PROVIDER_USER}&password=${PROVIDER_PASS}&action=get_live_streams")"

if [ -z "$PROVIDER_JSON" ] || [ "$PROVIDER_JSON" = "null" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Provider returned empty or invalid JSON."
  exit 1
fi

# Save provider snapshot
echo "$PROVIDER_JSON" > "$PROVIDER_DEBUG"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
TEMPLOG="$BASE_DIR/.temp_sync.log"
: > "$TEMPLOG"

echo "TITLE SYNC — $TIMESTAMP" >> "$TEMPLOG"
echo "Provider: ${PROVIDER_URL}" >> "$TEMPLOG"
echo "──────────────────────────────────────────" >> "$TEMPLOG"
echo "" >> "$TEMPLOG"

UPDATED=0

# Mapping provider_stream_id -> local stream_id
MAPPING="$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e 'SELECT provider_stream_id, stream_id FROM providers_streams;')"

IFS=$'\n'
echo "Updated:" >> "$TEMPLOG"

for ROW in $MAPPING; do
  PID="$(echo "$ROW" | awk '{print $1}')"
  LID="$(echo "$ROW" | awk '{print $2}')"

  PNAME="$(echo "$PROVIDER_JSON" | jq -r ".[] | select(.stream_id==$PID) | .name")"
  if [ -z "$PNAME" ] || [ "$PNAME" = "null" ]; then
    continue
  fi

  LNAME="$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -N -e "SELECT stream_display_name FROM streams WHERE id=$LID;")"

  if [ "$PNAME" != "$LNAME" ]; then
    SAFE_PNAME="$(echo "$PNAME" | sed "s/'/\\\\'/g")"
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" -D"$DB_NAME" -e "UPDATE streams SET stream_display_name='$SAFE_PNAME' WHERE id=$LID;"
    echo "  • Stream $LID: \"$LNAME\" → \"$PNAME\"" >> "$TEMPLOG"
    UPDATED=$((UPDATED+1))
  fi
done

echo "" >> "$TEMPLOG"
if [ "$UPDATED" -gt 0 ]; then
  echo "RESULT: $UPDATED titles updated" >> "$TEMPLOG"
else
  echo "RESULT: No title changes" >> "$TEMPLOG"
fi
echo "──────────────────────────────────────────" >> "$TEMPLOG"
echo "" >> "$TEMPLOG"
echo "" >> "$TEMPLOG"

# Prepend new block to sync.log
if [ -f "$LOGFILE" ]; then
  cp "$LOGFILE" "$BASE_DIR/.old_sync.log"
  cat "$TEMPLOG" "$BASE_DIR/.old_sync.log" > "$LOGFILE"
  rm -f "$BASE_DIR/.old_sync.log"
else
  cp "$TEMPLOG" "$LOGFILE"
fi

rm -f "$TEMPLOG"

# Log rotation
if [ "${USE_PYTHON_ROTATION:-0}" = "1" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$LOGFILE" << 'EOF'
import sys, datetime, re

if len(sys.argv) < 2:
    sys.exit(0)

logfile = sys.argv[1]

try:
    with open(logfile, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
except FileNotFoundError:
    sys.exit(0)

entries = []
current = []

for line in lines:
    if line.startswith("TITLE SYNC — "):
        if current:
            entries.append(current)
        current = [line]
    else:
        if current:
            current.append(line)
if current:
    entries.append(current)

now = datetime.datetime.now()
kept = []

for block in entries:
    header = block[0]
    m = re.search(r"TITLE SYNC — (\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})", header)
    if not m:
        continue
    dt = datetime.datetime.strptime(m.group(1) + " " + m.group(2), "%Y-%m-%d %H:%M:%S")
    if (now - dt).days <= 7:
        kept.append(block)

out_lines = []
for block in kept:
    out_lines.extend(block)

with open(logfile, "w", encoding="utf-8") as f:
    f.write("\n".join(out_lines).rstrip() + "\n")
EOF
else
  # Fallback: keep last 20 sync blocks if python3 not available
  TMPBLOCKS="$BASE_DIR/.blocks"
  grep -n "^TITLE SYNC — " "$LOGFILE" | cut -d: -f1 > "$TMPBLOCKS" 2>/dev/null || true
  TOTAL="$(wc -l < "$TMPBLOCKS" 2>/dev/null || echo 0)"
  KEEP=20
  if [ "$TOTAL" -gt "$KEEP" ]; then
    START_LINE="$(sed -n "$((TOTAL-KEEP+1))p" "$TMPBLOCKS")"
    sed -i "1,$((START_LINE-1))d" "$LOGFILE"
  fi
  rm -f "$TMPBLOCKS"
fi
