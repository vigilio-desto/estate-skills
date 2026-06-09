---
name: estate-health-watchdog
description: "No-agent watchdog cron that checks API health, web markers, and content count drift. Silent on OK, alerts on drift."
version: 1.0.0
tags: [watchdog, health, monitoring, estate]
metadata:
  author: Trentuna Estate
  license: MIT
---

# Estate Health Watchdog

A no-agent Hermes cron pattern that runs periodic health checks on your AI estate, alerting only on drift.

## Installation

```bash
hermes cron create \
  --name estate-health-watchdog \
  --script scripts/freshness-check.sh \
  --schedule "*/15 * * * *"
```

## Configuration

Set these environment variables in your Hermes profile:
- `ESTATE_URL` — base URL of your estate (default: http://localhost:8000)
- `CONTENT_COUNT_THRESHOLD` — min expected content count
- `WATCHDOG_ALERT_CHANNEL` — gateway channel for alerts (e.g., matrix, telegram)

## Behavior

- Silent exit on OK
- Prints diagnostic on drift or failure
- Hermes gateway delivers the output on non-zero exit
