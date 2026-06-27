# Grafana

Grafana is an open-source dashboarding tool that visualises data from an external source. In this project that source is Prometheus. Rather than building a custom visualisation layer, Grafana handles that work out of the box, and its dashboards can be customised and extended as the project grows without starting from scratch.

---

## Why it runs on the Raspberry Pi

Same reasoning as Prometheus, with one addition.

- **Dashboards stay up even when the server does not.** If Grafana lived on the server, it would go down the moment you needed it most — during a crash or a deployment gone wrong. On the Pi, the dashboards keep running, including the ones showing you that the server is down.
- **No extra ports needed for remote access.** Once you are connected via WireGuard, Grafana is reachable at its normal address (`http://192.168.1.50:3100`). Nothing extra to open on the server side.
- **The Pi is low-power and always on.** Grafana is meant to run continuously. The Pi handles that without adding load to the old PC.

For the broader Pi architecture, see [raspberry-pi.md](raspberry-pi.md). For how Prometheus feeds data into Grafana, see [prometheus.md](prometheus.md).

---

## Setup

Grafana runs as a Docker container on the Pi alongside Prometheus and Alertmanager, managed by `docker-compose.monitoring.yml` in the `Home_Lab` repo.

Once `bootstrap-pi.sh` has run and Docker is installed:

```bash
cd ~/Home_Lab
docker compose -f docker-compose/docker-compose.monitoring.yml up -d
```

Grafana will be at `http://192.168.1.50:3100` on the LAN, or via WireGuard when remote.

**Credentials** are set via `.env.grafana` on the Pi (created by `setup-env-pi.sh` before bootstrap runs). The default in that file is `admin`/`admin` — change it when prompted on first login, or set a strong password when running `setup-env-pi.sh`.

**Data source and dashboards are provisioned automatically** on first startup via the following files in the repo:

| File | Purpose |
|---|---|
| `grafana/provisioning/datasources/datasource.yml` | Connects Grafana to Prometheus at `http://prometheus:9090` |
| `grafana/provisioning/dashboards/dashboard.yml` | Tells Grafana where to load dashboard JSON files from |
| `grafana/provisioning/dashboards/system-overview.json` | Starting dashboard with request rate panels for prod and staging |

No manual UI steps are needed for the initial data source or dashboard setup — they load automatically when the container starts.

**Adding dashboards:**
- Pre-built dashboards are available at [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards) and can be imported by ID directly from the UI, or added as JSON files to `grafana/provisioning/dashboards/` and committed to the repo.
- For application-level metrics from `prom-client` (request count, response time, active requests), build panels using the metric names defined in the API's Prometheus middleware.
- System-level panels (CPU, memory, disk) can be added once Node Exporter is deployed on the old PC.

---

## Open items

- Configure Discord webhook in Alertmanager for notifications when a target goes down — see `alertmanager/config.yml` and [prometheus.md](prometheus.md).
- Expand `system-overview.json` with more panels as the project grows.
- Add system-level metric panels (CPU, memory, disk) once Node Exporter is deployed on the old PC.