#!/usr/bin/env bash
# =====================================================================
#  🧠 Safe WP Rocket Sitemap Preloader
#  Author: Privatedevops Ltd  |  https://privatedevops.com
#  Version: 1.5
#
#  Description:
#  ------------------------------------------------------------
#  A safe, sitemap-driven cache preloader for WP Rocket.
#  Optionally, preload all WordPress media (uploads images only)
#  referenced in each page using the `-m` flag.
#
#  Features:
#  ------------------------------------------------------------
#   ✅ Page-by-page preload (no mass purge)
#   ✅ Recursively follows sitemap index structure
#   ✅ Load-aware (pauses if system load is too high)
#   ✅ Prevents duplicate execution (via lock file)
#   ✅ Optional media preload (-m) for /wp-content/uploads/
#   ✅ WebP-aware: warms WebP Express + Cloudflare caches
#   ✅ Logs with color-coded console output
#   ✅ Prints total runtime
#
#  Usage:
#  ------------------------------------------------------------
#     ./preload <sitemap-url> [-p <parallel_jobs>] [-m]
#
#  Example:
#     ./preload https://gtime.bg/sitemap_index.xml -p 2 -m
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
USER_AGENT="PrivatedevopsLtd-WPRocketPreloader/1.5 (+https://privatedevops.com; ${DOMAIN})"
LOCK_FILE="/tmp/${DOMAIN}.preload.lock"
WEBP_HEADER="Accept: image/webp,image/apng,image/*,*/*;q=0.8"

# --- Args check ---
if [ -z "$SITEMAP_URL" ]; then
  echo "Usage: $0 <sitemap-index-or-url> [-p concurrency] [-m preload_media]"
  exit 1
fi

# --- Optional flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p)
      PARALLEL_JOBS="$2"; shift 2 ;;
    -m)
      PRELOAD_MEDIA=true; shift ;;
    *)
      shift ;;
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
[[ "$PRELOAD_MEDIA" == true ]] && echo -e "🖼  Media preload: ${YELLOW}enabled (uploads only, WebP-aware)${NC}"
echo "🕒 Started: $(date)" | tee "$LOG_FILE"

# --- Function to extract <loc> URLs from sitemap (supports .gz) ---
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

# --- Collect all sitemap URLs recursively ---
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
  while true; do
    LOAD=$(awk '{print $1}' /proc/loadavg)
    if (( $(echo "$LOAD < $MAX_LOAD" | bc -l) )); then break; fi
    echo -e "${YELLOW}⏸ System load high ($LOAD ≥ $MAX_LOAD), waiting...${NC}"
    sleep 5
  done

  local start=$(date +%s%3N)
  local html=$(curl -s --compressed --max-time 30 -A "$USER_AGENT" -H "$WEBP_HEADER" "$url")
  local end=$(date +%s%3N)
  local duration_ms=$((end - start))
  local duration_s=$(awk "BEGIN {printf \"%.3f\", $duration_ms / 1000}")

  echo -e "${BLUE}$(date '+%H:%M:%S')${NC} → ${GREEN}Preloaded${NC} ${GRAY}$url${NC}  ⏱ ${YELLOW}${duration_s}s${NC}"
  echo "$(date '+%H:%M:%S') → Preloaded $url  ⏱ ${duration_s}s" >> "$LOG_FILE"

  # --- Optionally preload only uploads images (WebP-aware) ---
  if [[ "$PRELOAD_MEDIA" == true && -n "$html" ]]; then
    echo -e "   ${GRAY}↳ Scanning uploads in $url...${NC}"
    echo "$html" |
      grep -Eo 'https?://[^"]+/wp-content/uploads/[^"]+\.(jpg|jpeg|png|webp|gif)' |
      sort -u |
      while read -r img; do
        curl -s -I --compressed --max-time 15 -A "$USER_AGENT" -H "$WEBP_HEADER" "$img" >/dev/null
        echo -e "      ${YELLOW}↪ Warmed${NC} ${GRAY}$img${NC}" >> "$LOG_FILE"
        sleep 0.15
      done
  fi
}
export -f preload_url
export USER_AGENT LOG_FILE MAX_LOAD RED GREEN BLUE YELLOW GRAY NC PRELOAD_MEDIA WEBP_HEADER

# --- Run preload (parallel-safe) ---
printf "%s\n" "${ALL_URLS[@]}" | xargs -n 1 -P "$PARALLEL_JOBS" bash -c 'preload_url "$@"' _

# --- Total duration ---
TOTAL_END=$(date +%s%3N)
TOTAL_MS=$((TOTAL_END - TOTAL_START))
TOTAL_SEC=$(awk "BEGIN {printf \"%.2f\", $TOTAL_MS / 1000}")

printf "✅ Finished preload for %b%s%b at %b%s%b (duration: %b%.2fs%b)\n" \
  "$GREEN" "$DOMAIN" "$NC" "$YELLOW" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC" "$YELLOW" "$TOTAL_SEC" "$NC" | tee -a "$LOG_FILE"

printf "🗒   Log saved: %b%s%b\n" "$GRAY" "$LOG_FILE" "$NC" | tee -a "$LOG_FILE"

# --- Cleanup ---
rm -f "$LOCK_FILE"
