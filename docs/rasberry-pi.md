# Raspberry Pi
 
**IP:** `192.168.1.50` · **OS:** Raspberry Pi OS Lite (64-bit) · **Role:** Network Services (always-on)
 
The Raspberry Pi is physically and logically separate from the homelab server (`hp-z240-server`, `192.168.1.30`). Its purpose is to give the homelab a layer of reliability that doesn't depend on the server being healthy — so that monitoring, remote access, and diagnostics still work even if the server crashes.
 
This separation is intentional: **the thing that monitors and provides access to the system should not share a single point of failure with the system itself.** If the VPN or monitoring lived on the server, a server crash would lock you out at exactly the moment you need access most.
 
---
 
## Responsibilities
 
### 1. Monitoring — Prometheus + Grafana
 
The Pi runs Prometheus and Grafana to monitor the homelab's dev, staging, and prod environments.
 
| Service | Port | Purpose |
|---|---|---|
| Prometheus | `:9090` | Scrapes `/metrics` from all environments |
| Grafana | `:3100` | Dashboards built on Prometheus data |
 
**How data flows:**
- Each API (dev/staging/prod) exposes a `/metrics` endpoint via `prom-client`. This endpoint is **stateless** — it only reports current snapshot values (current request count, memory, etc.) at the moment it's queried. The API itself never stores metrics history.
- Prometheus, running on the Pi, **pulls** from each `/metrics` endpoint on a fixed interval (15s). Each scrape is appended to Prometheus's own local time-series database, stored on the Pi's disk.
- Grafana, also on the Pi, reads from Prometheus to render dashboards.
```
API (old PC) → exposes current snapshot at /metrics
Prometheus (Pi) → scrapes every 15s → writes time-series history to its own local disk
Grafana (Pi) → reads from Prometheus → renders dashboards
```
 
**Why this matters for reliability:** because all historical metrics data lives on the Pi's own storage — not the server's — Prometheus retains everything it already collected even if the old PC goes down. This means you can see exactly what the system was doing in the moments before a crash, with no extra design needed; it falls out naturally from Prometheus's pull-based architecture.
 
**Open question for later:** disk retention policy (e.g., keep 30 days of metrics) needs to be configured once Prometheus is actually deployed, to prevent unbounded storage growth on the Pi.
 
### 2. VPN Gateway — WireGuard
 
The Pi also hosts the WireGuard VPN server, providing secure remote access to the entire LAN from outside the home network.
 
| Service | Port | Purpose |
|---|---|---|
| WireGuard | `:51820` (UDP) | VPN tunnel endpoint |
 
- The router forwards UDP port `51820` to the Pi. This is the **only port ever exposed externally** — everything else (nginx, Grafana, the APIs) stays LAN/VPN-only.
- Once a device authenticates via WireGuard's cryptographic handshake, it's treated as part of the LAN (or a dedicated VPN subnet, `10.0.0.0/24`) and can reach internal services exactly as if physically present at home.
- This is a stronger trust model than "physically on the LAN" — trust is based on possessing an approved private key, not network location.
**Why WireGuard runs on the Pi and not the server:**
- **Availability** — the old PC is the active development/deployment target and may be restarted or experimented on; the Pi is dedicated and stable.
- **Blast radius** — if the VPN endpoint were compromised, hosting it separately from the API/Mongo/nginx stack limits what's reachable from that foothold.
- **Independent diagnosis** — if the server crashes, VPN access (and therefore Grafana/Prometheus) stays up, letting you remotely diagnose what went wrong instead of being locked out.
- **Resource decoupling** — remote connection load doesn't compete with the server's actual application traffic.
**Implementation notes (not yet built):**
- WireGuard must run directly on the Pi's OS, not in a container. It needs to create a host-level network interface (`wg0`) and modify host routing/`iptables` rules to forward VPN traffic into the LAN — this requires host-level network access that conflicts with the isolation a container is meant to provide.
- IP forwarding must be enabled on the Pi (`net.ipv4.ip_forward=1`) with `PostUp`/`PostDown` `iptables` rules in `wg0.conf`, so VPN clients can reach the whole LAN, not just the Pi itself.
- A DDNS provider (DuckDNS / no-ip) is needed so the home network remains reachable even when the public IP changes.
---
 
## Request flow once both pieces are live
 
There is no separate reverse proxy on the Pi — nginx (on the old PC) remains the only reverse proxy in the system. WireGuard's job ends at "this device is now part of the LAN"; nginx picks up from there exactly as it would for a local device.
 
```
Remote:
  Phone → WireGuard tunnel (UDP 51820, Pi) → now virtually on home LAN
        → http://staging.local (port 80) → nginx (old PC) → drink_api_staging
 
Local:
  Laptop → http://staging.local (port 80) → nginx (old PC) → drink_api_staging
```
 
---
 
## Security boundary summary
 
| Layer | Responsibility |
|---|---|
| Firewall (`ufw`) | Decides *who* (which IP/subnet) may attempt a connection to a given port, before any request reaches an app |
| WireGuard | Decides *who* is allowed to join the LAN remotely, via cryptographic peer authentication |
| nginx | Decides, for requests that got through the firewall, *which backend* handles them, based on hostname |
 
Once `5001`/`5002` are firewalled to localhost-only (planned, not yet done), the only paths to the API are: physically on the LAN → port 80 → nginx, or authenticated via WireGuard → treated as LAN → port 80 → nginx. Nginx is not "bypassable" via direct port-80 access because nginx *is* the process bound to port 80 — there is nothing to go around.
 
---
 
## Status
 
| Component | Status |
|---|---|
| Pi static IP + SSH | Not yet configured |
| Docker on Pi | Not yet installed |
| Prometheus deployment | Not started |
| Grafana deployment | Not started |
| WireGuard install | Not started |
| Router port forward (51820 → Pi) | Not started |
| `ufw` lockdown of 5001/5002 to localhost-only | Deferred — flagged during nginx work, not yet implemented |
 
## Open items / future improvements
 
- Resolve and remove the stale "WireGuard on old PC" reference if it still exists elsewhere in the architecture docs — the Pi is the confirmed host.
- Define Prometheus retention policy before deployment (avoid unbounded disk growth on Pi).
- Decide on alerting transport (email vs Discord/Slack/ntfy.sh webhook) for Grafana alerts.
- Add Uptime Kuma on the Pi for a simple external uptime percentage, separate from Prometheus/Grafana.
- Once VPN is live, test full remote access end-to-end (disconnect from home WiFi, connect via VPN, confirm `staging.local`/`api.local`/Grafana all resolve and respond identically to local access).