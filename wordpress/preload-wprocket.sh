#!/usr/bin/env bash

# =====================================================================
#  🌀 Safe WP Rocket Sitemap Preloader
#  ---------------------------------------------------------------------
#  Author: Privatedevops Ltd
#  Website: https://privatedevops.com
#  Version: 1.2.0
#  License: MIT
#
#  Description:
#   A safe and efficient way to preload (warm) the WP Rocket cache using
#   your sitemap index — page by page — without flushing or overloading
#   your server.
#
#  How it works:
#   - Recursively parses all sitemap and child sitemap URLs.
#   - Requests each page individually using curl with a custom User-Agent.
#   - Waits a few seconds between requests to minimize load.
#   - Writes detailed logs with timing information for each page.
#
#  Example usage:
#     ./preload https://example.com/sitemap_index.xml
#     ./preload https://example.com/sitemap.xml
#     ./preload https://example.com/      # works with homepage too
#
#  Log file:
#     /tmp/<domain>_wp_preload.log
#
#  Author signature:
#     🧠 Privatedevops Ltd - Cloud & Server Optimization Experts
# =====================================================================

SITEMAP_URL="$1"
WAIT_TIME=2

# --- Extract domain name from the sitemap URL ---
DOMAIN=$(echo "$SITEMAP_URL" | awk -F[/:] '{print $4}')
LOG_FILE="/tmp/${DOMAIN}_wp_preload.log"
USER_AGENT="PrivatedevopsLtd-WPRocketPreloader/1.1 (+https://privatedevops.com; ${DOMAIN})"

if [ -z "$SITEMAP_URL" ]; then
  echo "Usage: $0 <sitemap-index-or-url>"
  exit 1
fi

echo "🚀 Starting WP Rocket safe preload for: ${DOMAIN}"
echo "🌐 Target: $SITEMAP_URL"
echo "🕒 Started: $(date)" | tee "$LOG_FILE"

# --- Function: extract <loc> URLs from sitemap (supports .gz) ---
get_urls() {
  local url="$1"
  local tmp=$(mktemp)
  if [[ "$url" == *.gz ]]; then
    echo "📦 Decompressing sitemap: $url" | tee -a "$LOG_FILE"
    curl -s --compressed --max-time 30 --retry 3 -A "$USER_AGENT" "$url" | gunzip -c > "$tmp"
  else
    curl -s --compressed --max-time 30 --retry 3 -A "$USER_AGENT" "$url" > "$tmp"
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

for url in "${ALL_URLS[@]}"; do
  START_TIME=$(date +%s%3N)
  printf "%(%H:%M:%S)T → Preloading %s" -1 "$url" | tee -a "$LOG_FILE"

  curl -s -I --compressed --max-time 30 --retry 2 -A "$USER_AGENT" "$url" >/dev/null

  END_TIME=$(date +%s%3N)
  DURATION_MS=$((END_TIME - START_TIME))
  DURATION_SEC=$(awk "BEGIN {printf \"%.2f\", $DURATION_MS/1000}")

  echo "  →  ⏱ ${DURATION_SEC}s" | tee -a "$LOG_FILE"
  sleep "$WAIT_TIME"
done

echo "✅ Finished preload for ${DOMAIN} at $(date)" | tee -a "$LOG_FILE"
echo "🗒 Log saved to: $LOG_FILE"
