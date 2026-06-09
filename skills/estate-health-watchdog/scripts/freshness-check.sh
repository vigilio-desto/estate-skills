#!/usr/bin/env bash
#
# freshness-check.sh  —  no_agent watchdog for estate health monitoring
#
# Checks:
#   1. API /api/garden endpoint          — estate pulse source
#   2. Frontend homepage                 — expected content markers
#   3. Content listing page              — file count vs served count
#   4. API estate status + disk metrics  — degrade detection
#
# Watchdog pattern: silent (empty stdout) on all OK, alerts on any drift.
# Designed for Hermes no_agent cron — non-zero exit delivers output via gateway.
# ────────────────────────────────────────────────────────────────────────────

set -o pipefail

# ── Configurable through env vars (all have safe defaults) ─────────────────
ESTATE_API_URL="${ESTATE_API_URL:-http://localhost:8000}"
ESTATE_FRONTEND_URL="${ESTATE_FRONTEND_URL:-http://localhost:3003}"

# Content directories to monitor — /var/data/ is the recommended default
ESSAYS_DIR="${ESSAYS_DIR:-/var/data/essays}"
SESSION_DIR="${SESSION_DIR:-/var/data/session}"
EXPRESSIVE_DIR="${EXPRESSIVE_DIR:-/var/data/expressive}"

# Homepage content markers (regex patterns to search for on the homepage)
HOMEPAGE_MARKER_1="${HOMEPAGE_MARKER_1:-estate-pulse}"
HOMEPAGE_MARKER_2="${HOMEPAGE_MARKER_2:-section-label}"
NODE_NAME_MARKER="${NODE_NAME_MARKER:-<node-name>}"

# Content listing page path (relative to frontend URL)
CONTENT_LIST_PATH="${CONTENT_LIST_PATH:-/essays}"

# CSS class / HTML pattern used to count served content items
CONTENT_CARD_PATTERN="${CONTENT_CARD_PATTERN:-class=\"[^\"]*card-title[^\"]*\"}"

# ── State ──────────────────────────────────────────────────────────────────
ALERTS=""

alert() { ALERTS="${ALERTS}$*\n"; }

# ── 1. API health check ───────────────────────────────────────────────────
api_json="$(timeout 10 curl -sf "$ESTATE_API_URL/api/garden" 2>/dev/null)" \
  || alert "[WARN] API /api/garden unreachable at $ESTATE_API_URL"

# ── 2. Frontend homepage check ────────────────────────────────────────────
homepage_html="$(timeout 10 curl -sf "$ESTATE_FRONTEND_URL" 2>/dev/null)" \
  || alert "[WARN] Frontend homepage unreachable at $ESTATE_FRONTEND_URL"

# ── 3. Content listing page check ─────────────────────────────────────────
content_html="$(timeout 10 curl -sf "${ESTATE_FRONTEND_URL}${CONTENT_LIST_PATH}" 2>/dev/null)" \
  || alert "[WARN] Content listing page unreachable at ${ESTATE_FRONTEND_URL}${CONTENT_LIST_PATH}"

# ── 4. Content markers on homepage ────────────────────────────────────────
if [ -n "$homepage_html" ]; then
  if ! echo "$homepage_html" | grep -q "$HOMEPAGE_MARKER_1"; then
    alert "[WARN] Homepage missing content marker: $HOMEPAGE_MARKER_1"
  fi
  if ! echo "$homepage_html" | grep -q "$HOMEPAGE_MARKER_2"; then
    alert "[WARN] Homepage missing content marker: $HOMEPAGE_MARKER_2"
  fi
  if ! echo "$homepage_html" | grep -qi "$NODE_NAME_MARKER"; then
    alert "[WARN] Homepage missing node name marker: $NODE_NAME_MARKER"
  fi
fi

# ── 5. File count: disk vs served ─────────────────────────────────────────
disk_count=0
if [ -d "$ESSAYS_DIR" ]; then
  # shellcheck disable=SC2012
  disk_count="$(ls -1 "$ESSAYS_DIR"/*.md 2>/dev/null | wc -l)"
fi

served_count=0
if [ -n "$content_html" ]; then
  served_count="$(echo "$content_html" | grep -o "$CONTENT_CARD_PATTERN" | wc -l)"
fi

if [ "$disk_count" -ne "$served_count" ]; then
  alert "[DRIFT] File count mismatch: $disk_count on disk vs $served_count served on ${CONTENT_LIST_PATH}"
fi

# ── 6. API data check ─────────────────────────────────────────────────────
if [ -n "$api_json" ]; then
  api_count="$(echo "$api_json" | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')"

  if [ -z "$api_count" ] || [ "$api_count" -eq 0 ] 2>/dev/null; then
    alert "[WARN] API reports zero count (possibly degraded)"
  fi

  estate_status="$(echo "$api_json" | grep -o '"status":"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')"
  disk_pct="$(echo "$api_json" | grep -o '"disk_pct":[0-9]*' | grep -o '[0-9]*')"
  disk_free="$(echo "$api_json" | grep -o '"disk_free_gb":[0-9.]*' | grep -o '[0-9.]*')"

  if [ -z "$estate_status" ]; then
    alert "[WARN] Could not parse API estate status"
  elif [ "$estate_status" != "idle" ] && [ "$estate_status" != "healthy" ]; then
    alert "[WARN] API estate status: $estate_status (expected: idle or healthy)"
  fi
fi

# ── 7. Additional directory health ────────────────────────────────────────
session_files=0
if [ -d "$SESSION_DIR" ]; then
  # shellcheck disable=SC2012
  session_files="$(ls -1 "$SESSION_DIR"/*.md 2>/dev/null | wc -l)"
fi

expressive_files=0
if [ -d "$EXPRESSIVE_DIR" ]; then
  # shellcheck disable=SC2012
  expressive_files="$(ls -1 "$EXPRESSIVE_DIR"/*.md 2>/dev/null | wc -l)"
fi

# ── 8. Output ─────────────────────────────────────────────────────────────
if [ -n "$ALERTS" ]; then
  echo "[estate-health-watchdog] $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "API count:           ${api_count:-unreachable}"
  echo "Estate status:       ${estate_status:-unreachable}"
  echo "Disk used:           ${disk_pct:-N/A}%  (free: ${disk_free:-N/A} GB)"
  echo "Served content:      $served_count items"
  echo "Disk content:        $disk_count files"
  echo "Session files:       $session_files"
  echo "Expressive files:    $expressive_files"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "$ALERTS"
  exit 1
fi

# Silent on OK — the watchdog pattern: empty stdout on healthy
exit 0
