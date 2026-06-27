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

## Open items

- Set a retention policy before deploying (e.g. `--storage.tsdb.retention.time=30d`) to cap disk usage on the Pi's NVMe.
- Set up Alertmanager for alert routing once the stack is running.
- Add Node Exporter to the old PC to expose system-level metrics (CPU, memory, disk) alongside the application metrics from `prom-client`.
- Consider Blackbox Exporter later for synthetic endpoint checks.