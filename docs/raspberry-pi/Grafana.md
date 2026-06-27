# Grafana

Grafana is an open-source dashboarding tool that visualises data from an external source. In this project that source is Prometheus. Rather than building a custom visualisation layer, Grafana handles that work out of the box — and its dashboards can be customised and extended as the project grows without starting from scratch.

---

## Why it runs on the Raspberry Pi

Same reasoning as Prometheus, with one addition.

- **Dashboards stay up even when the server does not.** If Grafana lived on the server, it would go down the moment you needed it most — during a crash or a deployment gone wrong. On the Pi, the dashboards keep running, including the ones showing you that the server is down.
- **No extra ports needed for remote access.** Once you are connected via WireGuard, Grafana is reachable at its normal address (`http://192.168.1.50:3100`). Nothing extra to open on the server side.
- **The Pi is low-power and always on.** Grafana is meant to run continuously. The Pi handles that without adding load to the old PC.

For the broader Pi architecture, see [raspberry-pi.md](raspberry-pi.md). For how Prometheus feeds data into Grafana, see [prometheus.md](prometheus.md).

---

## Setup

Grafana runs as a Docker container on the Pi alongside Prometheus, managed by `docker-compose.monitoring.yml` in the `Home_Lab` repo.

Once `bootstrap-pi.sh` has run and Docker is installed:

```bash
cd ~/Home_Lab
docker compose -f docker-compose/docker-compose.monitoring.yml up -d
```

Grafana will be at `http://192.168.1.50:3100` on the LAN, or via WireGuard when remote.

**First login:**
- Default credentials: `admin` / `admin`
- Change the password immediately when prompted.

**Adding Prometheus as a data source:**
1. Open Grafana at `http://192.168.1.50:3100`.
2. Go to **Connections → Data sources → Add data source**.
3. Select **Prometheus**.
4. Set the URL to `http://prometheus:9090` — this uses the Docker service name since both containers share a network in `docker-compose.monitoring.yml`.
5. Click **Save & test** and confirm it succeeds.

**Dashboards:**
- Pre-built dashboards are available at [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards) and can be imported by ID directly from the UI.
- For application-level metrics from `prom-client` (request count, response time, active requests), build a custom dashboard using the metric names defined in the API's Prometheus middleware.

---

## Open items

- Pick an alerting transport (email, Discord webhook, or ntfy.sh) for when a target goes down or a metric crosses a threshold.
- Persist dashboard and data source config to a volume in `docker-compose.monitoring.yml` so it survives container recreation.
- Look at Grafana provisioning (YAML-based config) to make the setup repeatable without manual UI steps after a fresh deploy.
- Add system-level metric panels (CPU, memory, disk) once Node Exporter is deployed on the old PC.