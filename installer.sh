#!/bin/bash

# XUI-One Title Sync Installer

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${GREEN}=== XUI-One Title Sync Installer ===${RESET}"

# 1) Auto-detect DB credentials from */xuione/credentials.txt
CRED_FILE="$(find / -type f -path "*/xuione/credentials.txt" 2>/dev/null | head -1)"

DB_USER=""
DB_PASS=""

if [[ -n "$CRED_FILE" ]]; then
  echo -e "${YELLOW}Found credentials file at: $CRED_FILE${RESET}"
  DB_USER="$(grep -i 'MySQL Username' "$CRED_FILE" | awk -F': ' '{print $2}')"
  DB_PASS="$(grep -i 'MySQL Password' "$CRED_FILE" | awk -F': ' '{print $2}')"
  echo -e "${YELLOW}Using DB user: $DB_USER${RESET}"
else
  echo -e "${RED}No xuione/credentials.txt found. DB credentials will be left as placeholders in config.env.${RESET}"
fi

# 2) Ask for provider details
echo -e "${YELLOW}Please enter your Provider (XC) details.${RESET}"
read -p "Provider URL (example: 144.76.200.209 or example.com): " PURL_RAW
PURL="http://${PURL_RAW}/player_api.php"

read -p "Provider Username: " PUSR
read -p "Provider Password: " PPASS"

# 3) Live provider connection test
echo -e "${YELLOW}Testing provider connection...${RESET}"
CHECK="$(curl -s "${PURL}?username=${PUSR}&password=${PPASS}")"

if [[ "$CHECK" == *"user_info"* ]]; then
  echo -e "${GREEN}Provider authentication OK.${RESET}"
else
  echo -e "${RED}Provider connection FAILED. Please check URL/username/password and try again.${RESET}"
  exit 1
fi

# 4) Ask how often to run the sync
echo -e "${YELLOW}How often should auto-sync run?${RESET}"
echo "1) Every 5 minutes"
echo "2) Every 15 minutes"
echo "3) Every 30 minutes"
echo "4) Every hour"
echo "5) Every 12 hours"
echo "6) Every 24 hours"
read -p "Select option (1-6): " OPT

case "$OPT" in
  1) INTERVAL="*/5 * * * *" ;;
  2) INTERVAL="*/15 * * * *" ;;
  3) INTERVAL="*/30 * * * *" ;;
  4) INTERVAL="0 * * * *" ;;
  5) INTERVAL="0 */12 * * *" ;;
  6) INTERVAL="0 0 * * *" ;;
  *) echo -e "${RED}Invalid option. Aborting.${RESET}"; exit 1 ;;
esac

# 5) Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo -e "${YELLOW}jq not found. Installing...${RESET}"
  apt update && apt install -y jq
else
  echo -e "${GREEN}jq already installed.${RESET}"
fi

# 6) Ensure python3 is installed and sane
USE_PYTHON_ROTATION=0
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${YELLOW}python3 not found. Trying to install...${RESET}"
  apt update && apt install -y python3 || echo -e "${RED}Failed to install python3.${RESET}"
fi

if command -v python3 >/dev/null 2>&1; then
  echo -e "${YELLOW}Running python3 sanity test...${RESET}"
  if python3 - << 'EOF'
import sys, datetime, re
print("OK")
EOF
  then
    echo -e "${GREEN}Python3 sanity test OK. Using Python-based log rotation.${RESET}"
    USE_PYTHON_ROTATION=1
  else
    echo -e "${RED}Python3 sanity test FAILED. Fallback log rotation will be used.${RESET}"
    USE_PYTHON_ROTATION=0
  fi
else
  echo -e "${RED}python3 is not available. Fallback log rotation will be used.${RESET}"
  USE_PYTHON_ROTATION=0
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

USE_PYTHON_ROTATION="${USE_PYTHON_ROTATION}"
EOF

echo -e "${GREEN}config.env created at: $CONFIG_FILE${RESET}"

# 8) Make title_sync.sh executable
chmod +x "$BASE_DIR/title_sync.sh"

# 9) Install cronjob
CRONLINE="${INTERVAL} ${BASE_DIR}/title_sync.sh >/dev/null 2>&1"
echo -e "${YELLOW}Installing cronjob...${RESET}"
( crontab -l 2>/dev/null | grep -v 'title_sync.sh' ; echo "$CRONLINE" ) | crontab -

echo -e "${GREEN}Installation complete.${RESET}"
echo -e "${YELLOW}Cron job will run with interval: $INTERVAL${RESET}"
echo -e "${YELLOW}Cron file location (for root user): /var/spool/cron/crontabs/root${RESET}"
echo -e "${YELLOW}Info log: ${BASE_DIR}/sync.log${RESET}"
echo -e "${YELLOW}Provider debug JSON: ${BASE_DIR}/provider.json${RESET}"
