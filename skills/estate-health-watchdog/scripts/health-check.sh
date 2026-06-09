#!/usr/bin/env bash
# Estate Health Watchdog — no-agent Hermes cron
set -euo pipefail

ESTATE_URL="${ESTATE_URL:-http://localhost:8000}"
CONTENT_COUNT_MIN="${CONTENT_COUNT_MIN:-1}"
PASS=true

check_endpoint() {
    local url="$1"
    local label="$2"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    if [ "$status" != "200" ]; then
        echo "[FAIL] $label — HTTP $status"
        PASS=false
    fi
}

check_content_count() {
    local url="$1"
    local count
    count=$(curl -s "$url" --max-time 10 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('entries',d.get('results',[]))))" 2>/dev/null || echo "0")
    if [ "$count" -lt "$CONTENT_COUNT_MIN" ]; then
        echo "[FAIL] Content count: $count (min: $CONTENT_COUNT_MIN)"
        PASS=false
    fi
}

check_endpoint "$ESTATE_URL/api/health" "API health"
check_endpoint "$ESTATE_URL/" "Root page"
check_content_count "$ESTATE_URL/api/content"

if [ "$PASS" = false ]; then
    echo "[ALERT] Estate health check FAILED"
    exit 1
fi
echo "[OK] Estate health check passed"
