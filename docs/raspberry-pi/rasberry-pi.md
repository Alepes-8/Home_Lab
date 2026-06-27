# Raspberry Pi

**IP:** `192.168.1.50` · **OS:** Raspberry Pi OS Lite (64-bit) · **Role:** Network Services (always-on)

The Raspberry Pi runs separately from the homelab server (`hp-z240-server`, `192.168.1.30`). The point is simple: if the server goes down, you still want monitoring and remote access to work. Both of those things living on the same machine as the thing they're monitoring defeats the purpose.

---

## Responsibilities

### 1. Monitoring — Prometheus + Grafana

The Pi scrapes metrics from the homelab's dev, staging, and prod environments and makes them available through Grafana dashboards. For details on each tool, see [prometheus.md](prometheus.md) and [grafana.md](grafana.md).

| Service | Port | Purpose |
|---|---|---|
| Prometheus | `:9090` | Scrapes `/metrics` from all environments |
| Grafana | `:3100` | Dashboards built on Prometheus data |

**How it works:**

Each API exposes a `/metrics` endpoint via `prom-client`. That endpoint only reports current values — it has no history of its own. Prometheus on the Pi hits that endpoint every 15 seconds and stores the results in its own local database. Grafana reads from Prometheus to build dashboards.

```
API (old PC) → exposes current snapshot at /metrics
Prometheus (Pi) → scrapes every 15s → stores history on Pi disk
Grafana (Pi) → reads from Prometheus → renders dashboards
```

Because the history lives on the Pi, Prometheus keeps working even if the old PC crashes. You can see exactly what the metrics looked like before the failure — that's the whole point of running it separately.

**One thing to sort out later:** retention policy. Prometheus will write to disk indefinitely without a limit configured. Set something like `--storage.tsdb.retention.time=30d` once the stack is deployed.

### 2. VPN Gateway — WireGuard

The Pi runs the WireGuard VPN server, which is how you get into the homelab from outside the house. For setup, client configuration, and peer management, see [wireguard.md](wireguard.md).

| Service | Port | Protocol | Purpose |
|---|---|---|---|
| WireGuard | `51820` | UDP | VPN tunnel endpoint |

Once a device connects through WireGuard, it is treated as if it is on the home LAN. The trust comes from cryptographic keys, not physical network location — which is strictly stronger than "plugged into the router."

---

## Setup

The Pi setup follows a similar pattern to the server, but the tools are different. There is no application stack here — no nginx, no MongoDB, no API containers. Just WireGuard, Prometheus, and Grafana.

1. Flash **Raspberry Pi OS Lite (64-bit)** using Raspberry Pi Imager. Use the advanced settings panel (gear icon) to set the hostname, enable SSH, and configure your username and password before writing the card. This means you never need a monitor or keyboard once it boots.
2. Plug the Pi into the router via ethernet and power it on.
3. Find its IP in your router's DHCP client list and SSH in.
4. Clone the `Home_Lab` repo:
   ```bash
   git clone https://github.com/Alepes-8/Home_Lab.git
   cd Home_Lab
   ```
5. Run the bootstrap script:
   ```bash
   sudo bash scripts/bootstrap-pi.sh
   ```
6. Follow the next steps printed at the end of the script.

For router configuration (DHCP reservation and port forwarding), see [router-setup.md](router-setup.md).
For DDNS setup, see [ddns-setup.md](ddns-setup.md).
For WireGuard client setup, see [wireguard.md](wireguard.md).

---

## How requests flow

nginx on the old PC is the only reverse proxy. WireGuard just puts your device on the LAN — nginx handles the actual routing from there.

```
Remote:
  Phone → WireGuard (UDP 51820, Pi) → on home LAN
        → staging.local:80 → nginx → drink_api_staging

Local:
  Laptop → staging.local:80 → nginx → drink_api_staging
```

---

## Security layers

| Layer | What it does |
|---|---|
| Firewall (`ufw`) | Controls which IPs can reach which ports |
| WireGuard | Controls which devices can join the LAN remotely |
| nginx | Controls which backend handles each request |

Once `5001`/`5002` are locked to localhost-only (not done yet), the only way to reach the API from outside the server itself is through nginx on port 80. That applies to both LAN and VPN traffic.

---

## Status

| Component | Status |
|---|---|
| Pi hardware (Pi 5 4GB + NVMe HAT + case) | Ordered, arriving tomorrow |
| Pi static IP + SSH | Not yet configured |
| Docker on Pi | Not yet installed |
| Prometheus deployment | Not started |
| Grafana deployment | Not started |
| WireGuard install | Not started |
| Router port forward (51820 → Pi) | Not started |
| `ufw` lockdown of 5001/5002 to localhost-only | Deferred |

---

## Open items

- Set Prometheus retention policy before deploying to avoid unbounded disk growth.
- Pick an alerting transport for Grafana (email, Discord, or ntfy.sh webhook).
- Add Uptime Kuma for simple uptime tracking alongside Prometheus.
- Once VPN is live: disconnect from home WiFi, connect via WireGuard, confirm that `staging.local`, `homesystem.local`, and Grafana all respond the same as they do locally.