#!/bin/sh
# XUI-One Title Sync Installer (cron.d compatible)

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# Must be run as root
if [ "$(id -u)" -ne 0 ]; then
  printf "%sThis installer must be run as root (sudo).%s\n" "$RED" "$RESET"
  exit 1
fi

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

printf "%s=== XUI-One Title Sync Installer ===%s\n" "$GREEN" "$RESET"

# 1) Auto-detect DB credentials
CRED_FILE="$(find / -type f -path "*/xuione/credentials.txt" 2>/dev/null | head -n 1)"

DB_USER=""
DB_PASS=""

if [ -n "$CRED_FILE" ]; then
  printf "%sFound credentials file at: %s%s\n" "$YELLOW" "$CRED_FILE" "$RESET"
  DB_USER="$(grep -i 'MySQL Username' "$CRED_FILE" | awk -F': ' '{print $2}')"
  DB_PASS="$(grep -i 'MySQL Password' "$CRED_FILE" | awk -F': ' '{print $2}')"
  printf "%sUsing DB user: %s%s\n" "$YELLOW" "$DB_USER" "$RESET"
else
  printf "%sNo xuione/credentials.txt found. Credentials will be placeholders.%s\n" "$RED" "$RESET"
fi

# 2) Provider details
printf "%sPlease enter your Provider (XC) details.%s\n" "$YELLOW" "$RESET"
printf "Provider URL (IP/domain only): "
read PURL_RAW
PURL="http://$PURL_RAW/player_api.php"

printf "Provider Username: "
read PUSR
printf "Provider Password: "
read PPASS

# 3) Live provider connection test
printf "%sTesting provider connection...%s\n" "$YELLOW" "$RESET"
CHECK="$(curl -s "${PURL}?username=${PUSR}&password=${PPASS}")"

echo "$CHECK" | grep -q "user_info"
if [ $? -eq 0 ]; then
  printf "%sProvider authentication OK.%s\n" "$GREEN" "$RESET"
else
  printf "%sProvider connection FAILED. Check credentials.%s\n" "$RED" "$RESET"
  exit 1
fi

# 4) Sync interval selection
printf "%sHow often should auto-sync run?%s\n" "$YELLOW" "$RESET"
printf "1) Every 5 minutes\n"
printf "2) Every 15 minutes\n"
printf "3) Every 30 minutes\n"
printf "4) Every hour\n"
printf "5) Every 12 hours\n"
printf "6) Every 24 hours\n"
printf "Select option (1-6): "
read OPT

case "$OPT" in
  1) INTERVAL="*/5 * * * *" ;;
  2) INTERVAL="*/15 * * * *" ;;
  3) INTERVAL="*/30 * * * *" ;;
  4) INTERVAL="0 * * * *" ;;
  5) INTERVAL="0 */12 * * *" ;;
  6) INTERVAL="0 0 * * *" ;;
  *) 
     printf "%sInvalid option. Aborting.%s\n" "$RED" "$RESET"
     exit 1
  ;;
esac

# 5) Install jq if missing
if ! command -v jq >/dev/null 2>&1; then
  printf "%sInstalling jq...%s\n" "$YELLOW" "$RESET"
  apt update && apt install -y jq
else
  printf "%sjq already installed.%s\n" "$GREEN" "$RESET"
fi

# 6) Python test for rotation
USE_PYTHON_ROTATION=0

if command -v python3 >/dev/null 2>&1; then
  printf "%sRunning python3 sanity test...%s\n" "$YELLOW" "$RESET"
  python3 - <<EOF >/dev/null 2>&1
import re, datetime
EOF
  if [ $? -eq 0 ]; then
    USE_PYTHON_ROTATION=1
    printf "%sPython3 sanity test OK.%s\n" "$GREEN" "$RESET"
  else
    printf "%sPython3 test FAILED. Using fallback log rotation.%s\n" "$RED" "$RESET"
  fi
else
  printf "%spython3 missing. Using fallback log rotation.%s\n" "$RED" "$RESET"
fi

# 7) Create config.env
CONFIG_FILE="$BASE_DIR/config.env"

cat > "$CONFIG_FILE" <<EOF
PROVIDER_URL="$PURL"
PROVIDER_USER="$PUSR"
PROVIDER_PASS="$PPASS"

DB_HOST="127.0.0.1"
DB_USER="${DB_USER:-YOUR_XUIONE_USER}"
DB_PASS="${DB_PASS:-YOUR_XUIONE_USER_DB_PASSWORD}"
DB_NAME="xui"

USE_PYTHON_ROTATION="$USE_PYTHON_ROTATION"
EOF

printf "%sconfig.env created at: %s%s\n" "$GREEN" "$CONFIG_FILE" "$RESET"

# 8) Make main script executable
chmod +x "$BASE_DIR/title_sync.sh"

# 9) Install cron via /etc/cron.d
CRON_FILE="/etc/cron.d/xuione-title-sync"
CRONLINE="${INTERVAL} root ${BASE_DIR}/title_sync.sh >/dev/null 2>&1"

printf "%sInstalling cron job in /etc/cron.d...%s\n" "$YELLOW" "$RESET"

{
  echo "# XUI-One Title Sync"
  echo "$CRONLINE"
} > "$CRON_FILE"

chmod 644 "$CRON_FILE"
chown root:root "$CRON_FILE"

printf "%sInstallation complete!%s\n" "$GREEN" "$RESET"
printf "%sCron file: %s%s\n" "$YELLOW" "$CRON_FILE" "$RESET"
printf "%sLogs: %s/sync.log%s\n" "$YELLOW" "$BASE_DIR" "$RESET"
