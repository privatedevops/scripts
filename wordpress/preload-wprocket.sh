#!/usr/bin/env bash
# =====================================================================
#  🧠 Safe WP Rocket Sitemap Preloader
#  Author: Privatedevops Ltd  |  https://privatedevops.com
#  Version: 1.6
#
#  Description:
#  ------------------------------------------------------------
#  A safe, sitemap-driven or single-URL preloader for WP Rocket.
#  Optionally preload all WordPress uploads images (/wp-content/uploads/)
#  referenced in each page using the `-m` flag.
#
#  Features:
#  ------------------------------------------------------------
#   ✅ Works with both sitemap indexes and single URLs
#   ✅ Recursively follows sitemap XMLs
#   ✅ Load-aware (pauses if system load too high)
#   ✅ Lock file prevents concurrent runs
#   ✅ Optional media preload (-m) for uploads only
#   ✅ Logs Cloudflare cache status (HIT/MISS/DYNAMIC)
#   ✅ Clean color-coded console output + total runtime
# =====================================================================

SITEMAP_URL="$1"
WAIT_TIME=2
MAX_LOAD=6
PARALLEL_JOBS=1
PRELOAD_MEDIA=false

# --- Colors ---
RED="\033[0;31m"; GREEN="\033[0;32m"; BLUE="\033[0;34m"
YELLOW="\033[1;33m"; GRAY="\033[0;37m"; NC="\033[0m"

# --- Extract domain name ---
DOMAIN=$(echo "$SITEMAP_URL" | awk -F[/:] '{print $4}')
LOG_FILE="/tmp/${DOMAIN}_wp_preload.log"
USER_AGENT="PrivatedevopsLtd-WPRocketPreloader/1.6 (+https://privatedevops.com; ${DOMAIN})"
LOCK_FILE="/tmp/${DOMAIN}.preload.lock"

# --- Args check ---
if [ -z "$SITEMAP_URL" ]; then
  echo "Usage: $0 <sitemap-or-url> [-p concurrency] [-m preload_media]"
  exit 1
fi

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) PARALLEL_JOBS="$2"; shift 2 ;;
    -m) PRELOAD_MEDIA=true; shift ;;
    *) shift ;;
  esac
done

# --- Prevent duplicate runs ---
if [ -f "$LOCK_FILE" ]; then
  echo -e "${RED}⚠ Preload already running for ${DOMAIN}!${NC} (lock: $LOCK_FILE)"
  exit 0
fi
touch "$LOCK_FILE"

# --- Start timer ---
TOTAL_START=$(date +%s%3N)
echo -e "🚀 Starting WP Rocket safe preload for: ${GREEN}${DOMAIN}${NC}"
echo "🌐 Target: $SITEMAP_URL"
[[ "$PRELOAD_MEDIA" == true ]] && echo -e "🖼  Media preload: ${YELLOW}enabled (uploads only)${NC}"
echo "🕒 Started: $(date)" | tee "$LOG_FILE"

# --- Function: extract <loc> URLs from sitemap (supports .gz) ---
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

# --- Detect sitemap vs single page ---
if [[ "$SITEMAP_URL" =~ \.xml$ ]]; then
  echo -e "${GRAY}🧭 Detected sitemap mode${NC}"
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
else
  echo -e "${GRAY}🌐 Detected single-page mode${NC}"
  ALL_URLS=("$SITEMAP_URL")
fi

# --- Preload Function ---
preload_url() {
  local url="$1"

  while true; do
    LOAD=$(awk '{print $1}' /proc/loadavg)
    if (( $(echo "$LOAD < $MAX_LOAD" | bc -l) )); then break; fi
    echo -e "${YELLOW}⏸ System load high ($LOAD ≥ $MAX_LOAD), waiting...${NC}"
    sleep 5
  done

  local start=$(date +%s%3N)
  local html=$(curl -s --compressed --max-time 30 -A "$USER_AGENT" "$url")
  local end=$(date +%s%3N)
  local duration_ms=$((end - start))
  local duration_s=$(awk "BEGIN {printf \"%.3f\", $duration_ms / 1000}")

  echo -e "${BLUE}$(date '+%H:%M:%S')${NC} → ${GREEN}Preloaded${NC} ${GRAY}$url${NC}  ⏱ ${YELLOW}${duration_s}s${NC}"
  echo "$(date '+%H:%M:%S') → Preloaded $url  ⏱ ${duration_s}s" >> "$LOG_FILE"

	# --- Optionally preload only uploads images (with CF status logging) ---
	if [[ "$PRELOAD_MEDIA" == true && -n "$html" ]]; then
	  echo -e "   ${GRAY}↳ Scanning uploads in $url...${NC}"

	  # Extract only clean, valid image URLs under /uploads/
	  echo "$html" | \
	    grep -Eo 'https?://[^"]+/wp-content/uploads/[^"]+\.(jpg|jpeg|png|webp|gif)' | \
	    grep -Ev "[\(\)\{\}'\"]" | \
	    grep -vE '\s' | \
	    sort -u | while read -r img; do

	      # Skip malformed or relative entries
	      [[ ! "$img" =~ ^https?://[a-zA-Z0-9.-]+/wp-content/uploads/ ]] && continue

	      # Fetch Cloudflare status
	      STATUS=$(curl -s -I --compressed --max-time 15 -A "$USER_AGENT" "$img" | tr -d '\r' | grep -i '^cf-cache-status:' | awk '{print $2}')
	      STATUS=${STATUS:-UNKNOWN}

	      # Skip invalid / broken URLs (UNKNOWN)
	      [[ "$STATUS" == "UNKNOWN" ]] && continue

	      # Print inline nicely
	      echo -e "      ${YELLOW}↪ Warmed${NC} ${GRAY}${img}${NC}  [${GREEN}${STATUS}${NC}]" | tee -a "$LOG_FILE"
	      sleep 0.15
	    done
	fi

}
export -f preload_url
export USER_AGENT LOG_FILE MAX_LOAD RED GREEN BLUE YELLOW GRAY NC PRELOAD_MEDIA

# --- Run preload ---
printf "%s\n" "${ALL_URLS[@]}" | xargs -n 1 -P "$PARALLEL_JOBS" bash -c 'preload_url "$@"' _

# --- Total duration ---
TOTAL_END=$(date +%s%3N)
TOTAL_MS=$((TOTAL_END - TOTAL_START))
TOTAL_SEC=$(awk "BEGIN {printf \"%.2f\", $TOTAL_MS / 1000}")

printf "\n✅ Finished preload for %b%s%b at %b%s%b (duration: %b%.2fs%b)\n" \
  "$GREEN" "$DOMAIN" "$NC" "$YELLOW" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC" "$YELLOW" "$TOTAL_SEC" "$NC" | tee -a "$LOG_FILE"
printf "🗒   Log saved: %b%s%b\n" "$GRAY" "$LOG_FILE" "$NC" | tee -a "$LOG_FILE"

rm -f "$LOCK_FILE"
