#!/usr/bin/env bash
# =====================================================================
#  🧠 Safe WP Rocket Sitemap Preloader
#  Author: Privatedevops Ltd  |  https://privatedevops.com
#  Version: 2.0
#
#  Description:
#  ------------------------------------------------------------
#  A safe, sitemap-driven or single-URL preloader for WP Rocket.
#  Optionally preload all WordPress uploads images (/wp-content/uploads/)
#  referenced in each page using the `-m` flag, and flush cache per URL with `-r`.
#
#  Features:
#  ------------------------------------------------------------
#   ✅ Works with both sitemap indexes and single URLs
#   ✅ Recursively follows sitemap XMLs
#   ✅ Load-aware (pauses if system load too high)
#   ✅ Lock file prevents concurrent runs
#   ✅ Optional media preload (-m) for uploads only
#   ✅ Optional per-URL cache flush (-r <document_root>)
#   ✅ Prevents running -r as root for safety
#   ✅ Validates wp-cli and WordPress installation presence
#   ✅ Logs Cloudflare cache status (HIT/MISS/DYNAMIC)
#   ✅ Clean color-coded console output + total runtime
# =====================================================================

WAIT_TIME=2
MAX_LOAD=6
PARALLEL_JOBS=1
PRELOAD_MEDIA=false
RESET_CACHE=false
DOCROOT=""

RED="\033[0;31m"; GREEN="\033[0;32m"; BLUE="\033[0;34m"
YELLOW="\033[1;33m"; GRAY="\033[0;37m"; NC="\033[0m"

show_usage() {
  echo -e "${YELLOW}Usage:${NC} $0 <sitemap-or-url> [-p concurrency] [-m] [-r <document_root>]"
  echo ""
  echo "Options:"
  echo "  -p <num>        Number of parallel preload jobs (default: 1)"
  echo "  -m              Enable media preload (uploads only)"
  echo "  -r <path>       Flush cache per URL (requires valid WordPress root)"
  echo ""
  echo "Examples:"
  echo "  $0 https://site.com/sitemap_index.xml -p 4"
  echo "  $0 https://site.com/sitemap_index.xml -m -r /var/www/html"
  exit 1
}

# --- Argument Parsing ---
SITEMAP_URL="$1"
if [ -z "$SITEMAP_URL" ]; then
  show_usage
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p)
      if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo -e "${RED}❌ Missing concurrency value after -p${NC}"; show_usage
      fi
      PARALLEL_JOBS="$2"; shift 2 ;;
    -m)
      PRELOAD_MEDIA=true; shift ;;
    -r)
      if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo -e "${RED}❌ Missing document root path after -r${NC}"; show_usage
      fi
      RESET_CACHE=true; DOCROOT="$2"; shift 2 ;;
    -h|--help)
      show_usage ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"; show_usage ;;
  esac
done

DOMAIN=$(echo "$SITEMAP_URL" | awk -F[/:] '{print $4}')
LOG_FILE="/tmp/${DOMAIN}_wp_preload.log"
USER_AGENT="PrivatedevopsLtd-WPRocketPreloader/2.0 (+https://privatedevops.com; ${DOMAIN})"
LOCK_FILE="/tmp/${DOMAIN}.preload.lock"

# --- Safety checks for -r mode ---
if [[ "$RESET_CACHE" == true ]]; then
  if [ ! -d "$DOCROOT" ]; then
    echo -e "${RED}❌ Invalid or missing document root: $DOCROOT${NC}"
    show_usage
  fi
  if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Refusing to run -r as root.${NC}"
    echo -e "   Run as the web user (e.g. ${YELLOW}www-data${NC})."
    exit 1
  fi
  if ! command -v wp >/dev/null 2>&1 && [ ! -f "${DOCROOT}/wp-cli.phar" ]; then
    echo -e "${RED}❌ wp-cli not found in PATH or ${DOCROOT}${NC}"
    exit 1
  fi
  # --- WordPress verification ---
  if [ ! -f "${DOCROOT}/wp-config.php" ] || [ ! -d "${DOCROOT}/wp-content" ]; then
    echo -e "${RED}❌ The provided path does not appear to be a WordPress root.${NC}"
    echo -e "   Expected: ${DOCROOT}/wp-config.php and wp-content/"
    exit 1
  fi
  echo -e "♻️  ${YELLOW}Per-URL cache flush enabled${NC} (WordPress root: ${GRAY}${DOCROOT}${NC})"
fi

# --- Prevent duplicate runs ---
if [ -f "$LOCK_FILE" ]; then
  echo -e "${RED}⚠ Preload already running for ${DOMAIN}!${NC} (lock: $LOCK_FILE)"
  exit 0
fi
touch "$LOCK_FILE"

TOTAL_START=$(date +%s%3N)
echo -e "🚀 Starting WP Rocket safe preload for: ${GREEN}${DOMAIN}${NC}"
echo "🌐 Target: $SITEMAP_URL"
[[ "$PRELOAD_MEDIA" == true ]] && echo -e "🖼  Media preload: ${YELLOW}enabled (uploads only)${NC}"
echo "🕒 Started: $(date)" | tee "$LOG_FILE"

# --- Function: extract <loc> URLs from sitemap ---
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

  if [[ "$RESET_CACHE" == true && -n "$DOCROOT" ]]; then
    echo -e "   ${GRAY}♻️  Resetting cache for:${NC} ${YELLOW}${url}${NC}"
    (cd "$DOCROOT" && wp rocket clean "$url" --quiet >/dev/null 2>&1)
  fi

  local start=$(date +%s%3N)
  local html=$(curl -s --compressed --max-time 30 -A "$USER_AGENT" "$url")
  local end=$(date +%s%3N)
  local duration_ms=$((end - start))
  local duration_s=$(awk "BEGIN {printf \"%.3f\", $duration_ms / 1000}")

  echo -e "${BLUE}$(date '+%H:%M:%S')${NC} → ${GREEN}Preloaded${NC} ${GRAY}$url${NC}  ⏱ ${YELLOW}${duration_s}s${NC}"
  echo "$(date '+%H:%M:%S') → Preloaded $url  ⏱ ${duration_s}s" >> "$LOG_FILE"

  if [[ "$PRELOAD_MEDIA" == true && -n "$html" ]]; then
    echo -e "   ${GRAY}↳ Scanning uploads in $url...${NC}"
    echo "$html" |
      grep -Eo 'https?://[^"]+/wp-content/uploads/[^"]+\.(jpg|jpeg|png|webp|gif)' |
      grep -Ev "[\(\)\{\}'\"]" | grep -vE '\s' | sort -u | while read -r img; do
        [[ ! "$img" =~ ^https?://[a-zA-Z0-9.-]+/wp-content/uploads/ ]] && continue
        STATUS=$(curl -s -I --compressed --max-time 15 -A "$USER_AGENT" "$img" | tr -d '\r' | grep -i '^cf-cache-status:' | awk '{print $2}')
        [[ -z "$STATUS" ]] && continue
        echo -e "      ${YELLOW}↪ Warmed${NC} ${GRAY}${img}${NC}  [${GREEN}${STATUS}${NC}]" | tee -a "$LOG_FILE"
        sleep 0.15
      done
  fi
}

export -f preload_url
export USER_AGENT LOG_FILE MAX_LOAD RED GREEN BLUE YELLOW GRAY NC PRELOAD_MEDIA RESET_CACHE DOCROOT

printf "%s\n" "${ALL_URLS[@]}" | xargs -n 1 -P "$PARALLEL_JOBS" bash -c 'preload_url "$@"' _

TOTAL_END=$(date +%s%3N)
TOTAL_MS=$((TOTAL_END - TOTAL_START))
TOTAL_SEC=$(awk "BEGIN {printf \"%.2f\", $TOTAL_MS / 1000}")

printf "\n✅ Finished preload for %b%s%b at %b%s%b (duration: %b%.2fs%b)\n" \
  "$GREEN" "$DOMAIN" "$NC" "$YELLOW" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC" "$YELLOW" "$TOTAL_SEC" "$NC" | tee -a "$LOG_FILE"
printf "🗒   Log saved: %b%s%b\n" "$GRAY" "$LOG_FILE" "$NC" | tee -a "$LOG_FILE"

rm -f "$LOCK_FILE"
