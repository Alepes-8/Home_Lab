# Prometheus

Prometheus is an open-source monitoring tool that collects and stores metrics from your services over time. In this project it scrapes the API's `/metrics` endpoint and feeds that data to Grafana for visualisation. It is the standard pairing for this kind of homelab monitoring setup — well-documented, widely used, and straightforward to debug when something goes wrong.

---

## Why it runs on the Raspberry Pi

There are three reasons Prometheus runs on the Pi rather than the server.

**If the server crashes, you want Prometheus to still be running.** That is the whole point of monitoring. If Prometheus lived on the same machine it was watching, it would go offline at exactly the moment you need it. On the Pi, it keeps collecting data, and you can see what the metrics looked like right before the failure.

**Running on the Pi forces Prometheus through nginx.** If Prometheus shared the Docker network on the server, it could reach the API containers directly, bypassing nginx entirely. That is not a realistic test — if nginx is broken, Prometheus would still report everything as healthy. Running it on the Pi means Prometheus takes the same path a real user would take, through port 80 and nginx, which gives an accurate picture of actual service availability.

**The Pi is low-power and always on.** Prometheus runs continuously. Keeping it on the Pi means it does not compete for resources with the application stack on the old PC.

For the broader Pi architecture, see [raspberry-pi.md](raspberry-pi.md).

---

## How scraping works

Prometheus uses a pull model. It does not receive data passively — it reaches out to each configured target and reads the current metrics snapshot. The API's `/metrics` endpoint only ever reports current values; it has no history of its own. Prometheus takes those snapshots every 15 seconds and writes them to its own local time-series database on the Pi's disk.

```
drink_api (old PC) → GET /metrics returns current values only
Prometheus (Pi)    → scrapes every 15s → stores history on Pi disk
Grafana (Pi)       → reads Prometheus → renders dashboards
```

The history is on the Pi. If the server goes down, the history stays intact.

---

## Setup

Prometheus runs as a Docker container on the Pi alongside Grafana, managed by `docker-compose.monitoring.yml` in the `Home_Lab` repo.

Once `bootstrap-pi.sh` has run and Docker is installed:

```bash
cd ~/Home_Lab
docker compose -f docker-compose/docker-compose.monitoring.yml up -d
```

Prometheus will be at `http://192.168.1.50:9090` on the LAN, or via WireGuard when remote.

**Scrape targets** are defined in `prometheus.yml`, mounted into the container via the compose file. Each environment gets its own job, scraping through nginx on port 80:

```yaml
scrape_configs:
  - job_name: 'drink_api_prod'
    static_configs:
      - targets: ['192.168.1.30:80']
    metrics_path: '/metrics'

  - job_name: 'drink_api_staging'
    static_configs:
      - targets: ['192.168.1.30:80']
    metrics_path: '/metrics'
```

The nginx `location /metrics` block needs to exist in each site config on the old PC before this will work. See `nginx/sites/homesystem.local.conf` and `nginx/sites/staging.local.conf`.

---

## Alertmanager

Prometheus evaluates alert rules and fires alerts, but it does not send notifications on its own. That is Alertmanager's job. When Prometheus detects that a rule condition has been met — say, a scrape target has been unreachable for two minutes — it pushes that alert to Alertmanager, which then routes it to a configured destination (Discord, email, etc.).

This means you can get notified when the server goes down without having to manually check Grafana or connect via WireGuard. Alertmanager handles deduplication and repeat intervals too, so you do not get spammed if something stays broken for hours.

Alertmanager has no awareness of your services on its own. It is purely downstream of Prometheus — nothing reaches it unless Prometheus sends it an alert first.

```
Prometheus evaluates rules → fires alert → pushes to Alertmanager → routes to Discord/email/etc
```

### How it is configured

Four files together make up the alerting setup:

**`docker-compose.monitoring.yml`** runs the Alertmanager container and mounts two things: the config file from the repo, and a named volume for persistent state. The volume matters because Alertmanager stores active silences and notification state on disk — without it, a container restart would forget any silences you had set.

**`alertmanager/config.yml`** tells Alertmanager where to send alerts and how often. Routes define which alerts go where, and receivers define the actual destination (webhook URL, email address, etc.). You can also separate critical alerts from general ones by routing them to different receivers. Currently configured with a placeholder receiver — no notifications are sent until a real transport is added.

**`prometheus/prometheus.yml`** tells Prometheus where Alertmanager is running (`alertmanager:9093`) and where to find the rule files to evaluate.

**`prometheus/rules/homelab.yml`** defines the actual alert conditions — what triggers an alert, how long the condition must hold before firing, and what severity to attach. Currently contains one rule: `TargetDown`, which fires when any scrape target has been unreachable for two minutes.

### Adding Discord later

When you are ready to add notifications, open `alertmanager/config.yml` and replace the placeholder receiver with:

```yaml
receivers:
  - name: 'discord'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_URL'
        title: 'Homelab Alert'
        message: '{{ .CommonAnnotations.summary }}'
```

Update `route.receiver` to `'discord'` and reload Alertmanager. No other files need to change.

---

## Open items

- Add Node Exporter to the old PC to expose system-level metrics (CPU, memory, disk) alongside the application metrics from `prom-client`.
- Configure Discord webhook in `alertmanager/config.yml` once notifications are wanted.
- Consider Blackbox Exporter later for synthetic endpoint checks.
- Add more alert rules to `prometheus/rules/homelab.yml` as the system grows (high memory, slow response times, etc.).