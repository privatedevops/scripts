#!/usr/bin/env bash
# =====================================================================
#  Safe WP Rocket Sitemap Preloader
#  https://privatedevops.com  –  by Privatedevops Ltd
#
#  Recursively crawls sitemap index URLs and warms WP Rocket cache
#  without purging it. Supports parallel execution (-p <threads>)
#  to preload multiple pages simultaneously.
#
#  Example:
#     ./preload https://gtime.bg/sitemap_index.xml -p 4
#
#  Notes:
#     - Safe, lightweight, no cache purge.
#     - Logs stored in /tmp/<domain>_wp_preload.log
# =====================================================================

SITEMAP_URL="$1"
shift
PARALLEL=1
WAIT_TIME=1

# --- Parse options ---
while getopts "p:" opt; do
  case $opt in
    p) PARALLEL="$OPTARG" ;;
    *) echo "Usage: $0 <sitemap-url> [-p threads]" && exit 1 ;;
  esac
done

if [ -z "$SITEMAP_URL" ]; then
  echo "Usage: $0 <sitemap-url> [-p threads]"
  exit 1
fi

# --- Extract domain ---
DOMAIN=$(echo "$SITEMAP_URL" | awk -F[/:] '{print $4}')
LOG_FILE="/tmp/${DOMAIN}_wp_preload.log"
USER_AGENT="PrivatedevopsLtd-WPRocketPreloader/1.1 (+https://${DOMAIN}; https://privatedevops.com)"

echo "🚀 Starting WP Rocket safe preload for: ${DOMAIN}"
echo "🌐 Target: ${SITEMAP_URL}"
echo "🧵 Threads: ${PARALLEL}"
echo "🕒 Started: $(date)" | tee "$LOG_FILE"

# --- Helper function: extract <loc> URLs from sitemap ---
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

# --- Collect all URLs ---
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

# --- Function to preload one URL ---
preload_url() {
  local url="$1"
  local start=$(date +%s%3N)
  curl -s -I --compressed --max-time 30 --retry 2 -A "$USER_AGENT" "$url" > /dev/null
  local end=$(date +%s%3N)
  local duration=$(awk "BEGIN {print ($end - $start)/1000}")
  printf "%s → Preloaded %s  ⏱ %.2fs\n" "$(date '+%H:%M:%S')" "$url" "$duration" | tee -a "$LOG_FILE"
}

export -f preload_url
export USER_AGENT LOG_FILE

# --- Run in parallel ---
printf "%s\n" "${ALL_URLS[@]}" | xargs -n1 -P"$PARALLEL" bash -c 'preload_url "$@"' _

echo "✅ Finished preload for ${DOMAIN} at $(date)"
echo "🗒 Log saved to: $LOG_FILE"
