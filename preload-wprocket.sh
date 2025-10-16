#!/usr/bin/env bash
# =====================================================================
#  Advanced WP Rocket Sitemap Preloader
#  https://privatedevops.com  –  by Privatedevops Ltd
#
#  Recursively crawls sitemap index URLs and warms WP Rocket cache
#  without purging it. Supports:
#   ✅ Parallel execution (-p threads)
#   ✅ Load protection (wait if system load > MAX_LOAD)
#   ✅ Lock file (prevents concurrent runs per domain)
#   ✅ Colored output & millisecond timing
#
#  Example:
#     ./preload https://gtime.bg/sitemap_index.xml -p 4
# =====================================================================

# --- Config ---
WAIT_TIME=1
MAX_LOAD=6.0   # System load threshold
PARALLEL=1

# --- Colors ---
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;36m"
GRAY="\033[0;37m"
NC="\033[0m" # No color

# --- Input ---
SITEMAP_URL="$1"
shift

while getopts "p:" opt; do
  case $opt in
    p) PARALLEL="$OPTARG" ;;
    *) echo "Usage: $0 <sitemap-url> [-p threads]" && exit 1 ;;
  esac
done

if [ -z "$SITEMAP_URL" ]; then
  echo -e "${RED}Usage:${NC} $0 <sitemap-url> [-p threads]"
  exit 1
fi

DOMAIN=$(echo "$SITEMAP_URL" | awk -F[/:] '{print $4}')
LOCK_FILE="/tmp/${DOMAIN}_wp_preload.lock"
LOG_FILE="/tmp/${DOMAIN}_wp_preload.log"
USER_AGENT="PrivatedevopsLtd-WPRocketPreloader/1.2 (+https://${DOMAIN}; https://privatedevops.com)"

# --- Lock check ---
if [ -f "$LOCK_FILE" ]; then
  echo -e "${YELLOW}⚠ Lock file exists for ${DOMAIN}. Another preload is running. Skipping.${NC}"
  echo "Active lock: $LOCK_FILE"
  exit 0
fi
trap "rm -f '$LOCK_FILE'" EXIT
touch "$LOCK_FILE"

# --- Header ---
echo -e "${GREEN}🚀 Starting WP Rocket safe preload for:${NC} ${BLUE}${DOMAIN}${NC}"
echo -e "${GRAY}🌐 Target:${NC} ${SITEMAP_URL}"
echo -e "${GRAY}🧵 Threads:${NC} ${PARALLEL}"
echo -e "${GRAY}🕒 Started:${NC} $(date)"
echo "Log: $LOG_FILE"
echo "Started at $(date)" > "$LOG_FILE"

# --- Helper: Extract <loc> URLs from sitemap ---
get_urls() {
  local url="$1"
  local tmp=$(mktemp)
  if [[ "$url" == *.gz ]]; then
    curl -s --compressed -A "$USER_AGENT" "$url" | gunzip -c > "$tmp"
  else
    curl -s --compressed -A "$USER_AGENT" "$url" > "$tmp"
  fi
  grep -oP '(?<=<loc>)[^<]+' "$tmp" | sed 's/[[:space:]]//g'
  rm -f "$tmp"
}

# --- Collect URLs recursively ---
ALL_URLS=()
TOP_URLS=($(get_urls "$SITEMAP_URL"))
for sm in "${TOP_URLS[@]}"; do
  if [[ "$sm" =~ sitemap.*\.xml$ ]]; then
    CHILD_URLS=($(get_urls "$sm"))
    ALL_URLS+=("${CHILD_URLS[@]}")
  else
    ALL_URLS+=("$sm")
  fi
done
ALL_URLS=($(printf "%s\n" "${ALL_URLS[@]}" | sort -u))

# --- Preload Function ---
preload_url() {
  local url="$1"

  # Wait for system load to drop
  while true; do
    LOAD=$(awk '{print $1}' /proc/loadavg)
    if (( $(echo "$LOAD < $MAX_LOAD" | bc -l) )); then
      break
    fi
    echo -e "${YELLOW}⏸ System load high ($LOAD ≥ $MAX_LOAD), waiting...${NC}"
    sleep 5
  done

  local start=$(date +%s%3N)
  curl -s -I --compressed --max-time 30 --retry 2 -A "$USER_AGENT" "$url" > /dev/null
  local end=$(date +%s%3N)
  local duration_ms=$((end - start))
  local duration_s=$(awk "BEGIN {print $duration_ms / 1000}")

  echo -e "${BLUE}$(date '+%H:%M:%S')${NC} → ${GREEN}Preloaded${NC} ${GRAY}$url${NC}  ⏱ ${YELLOW}${duration_s}s${NC}" | tee -a "$LOG_FILE"
}

export -f preload_url
export USER_AGENT LOG_FILE MAX_LOAD RED GREEN BLUE YELLOW GRAY NC

# --- Run in parallel ---
printf "%s\n" "${ALL_URLS[@]}" | xargs -n1 -P"$PARALLEL" bash -c 'preload_url "$@"' _

echo -e "${GREEN}✅ Finished preload for${NC} ${BLUE}${DOMAIN}${NC} at $(date)"
echo "Log saved: $LOG_FILE"
rm -f "$LOCK_FILE"
