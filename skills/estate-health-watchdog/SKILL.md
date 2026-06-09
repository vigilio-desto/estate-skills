---
name: estate-health-watchdog
description: "No-agent Hermes cron that monitors API health, web markers, file-count drift, and estate status. Silent on OK, alerts on any degradation or drift."
version: 1.0.0
license: MIT
tags: [watchdog, monitoring, health, cron, no-agent, estate]
platforms: [linux, macos]
compatibility:
  hermes: ">=0.4.0"
metadata:
  author: Trentuna Estate
  source: https://github.com/vigilio-desto/estate-skills
  skill_type: watchdog
---

# Estate Health Watchdog

A no-agent Hermes cron pattern that runs periodic health checks on your AI estate, alerting **only on drift**. Uses the `no_agent` cron mode — no LLM invoked on OK runs, zero token cost for healthy estates.

## What It Checks

| # | Check | What It Detects |
|---|-------|-----------------|
| 1 | API `/api/garden` endpoint | API server unreachable or down |
| 2 | Frontend homepage | Web server unreachable |
| 3 | Content listing page | Missing routes or static build failures |
| 4 | Homepage content markers | Missing expected text/regex patterns (wrong deploy, config drift) |
| 5 | File count: disk vs served | Publishing pipeline broke (new content not appearing, or missing items) |
| 6 | API estate status + disk metrics | Estate degraded, disk full, zero-count anomalies |
| 7 | Secondary directory health | Session/expressive dirs still present (prevent silent data loss) |

**Drift pattern** — item 5 is the most important: compares `.md` files on disk against rendered items on the content listing page. A mismatch means the publishing pipeline stopped working.

## Installation

```bash
# Register as a no-agent cron job (no LLM cost on healthy runs)
hermes cron create \
  --name estate-health-watchdog \
  --script skills/estate-health-watchdog/scripts/freshness-check.sh \
  --schedule "*/15 * * * *" \
  --no-agent
```

Or install directly from the repo:

```bash
hermes skills install github:vigilio-desto/estate-skills/skills/estate-health-watchdog
```

## Configuration

Set these environment variables in your Hermes profile (`~/.hermes/config.yaml` or `.env`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `ESTATE_API_URL` | `http://localhost:8000` | API server base URL |
| `ESTATE_FRONTEND_URL` | `http://localhost:3003` | Frontend web URL |
| `ESSAYS_DIR` | `/var/data/essays` | Content directory (compared against served count) |
| `SESSION_DIR` | `/var/data/session` | Session log directory (existence check) |
| `EXPRESSIVE_DIR` | `/var/data/expressive` | Expressive content directory (existence check) |
| `HOMEPAGE_MARKER_1` | `estate-pulse` | Regex pattern expected on homepage |
| `HOMEPAGE_MARKER_2` | `section-label` | Second regex pattern expected on homepage |
| `NODE_NAME_MARKER` | `<node-name>` | Node name expected on homepage |
| `CONTENT_LIST_PATH` | `/essays` | Relative path to content listing page |
| `CONTENT_CARD_PATTERN` | `class="[^"]*card-title[^"]*"` | HTML pattern for counting served items |

### Profile-Specific Override Example

```yaml
# ~/.hermes/config.yaml
env:
  ESTATE_API_URL: https://api.my-estate.com
  ESTATE_FRONTEND_URL: https://my-estate.com
  ESSAYS_DIR: /home/user/content/essays
  HOMEPAGE_MARKER_1: "my-estate-header-tag"
  CONTENT_CARD_PATTERN: "class=\"essay-card\""
```

## Behavior

- **All OK:** exits 0 with empty stdout — no notification sent.
- **Any drift/failure:** exits 1 with structured diagnostic output — Hermes gateway delivers the output to your configured alert channel.
- **First line on failure:** `[estate-health-watchdog] <ISO-timestamp>` for easy log correlation.

### Sample Alert Output

```
[estate-health-watchdog] 2026-06-09T14:30:00Z
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API count:           42
Estate status:       idle
Disk used:           68%  (free: 12.4 GB)
Served content:      38 items
Disk content:        45 files
Session files:       120
Expressive files:    15
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[DRIFT] File count mismatch: 45 on disk vs 38 served on /essays
```

## The no_agent Pattern

This skill demonstrates the Hermes no-agent watchdog pattern:

1. **Register with `--no-agent`** — the scheduler runs the script directly, no LLM invoked.
2. **Silent exit on healthy** — zero token cost, zero notifications for OK runs.
3. **Non-zero exit on alert** — Hermes captures stdout and delivers it via the gateway.
4. **All state is env-var-driven** — no hardcoded paths, credentials, or hostnames.

This is the recommended pattern for recurring infrastructure health checks. It costs nothing on happy days and alerts immediately on the first sign of trouble.

## Testing

```bash
# Dry-run to see what it would alert on
bash /path/to/freshness-check.sh

# Verify with custom config
ESTATE_API_URL=http://localhost:8000 \
ESTATE_FRONTEND_URL=http://localhost:3003 \
ESSAYS_DIR=/tmp/test-essays \
bash /path/to/freshness-check.sh
```
