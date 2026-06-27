# WireGuard

WireGuard is a free, open-source VPN you can self-host. It lets you reach your home network from anywhere, as if you were physically sitting on it. Devices that connect through WireGuard get an IP in the VPN subnet (`10.0.0.x`) rather than the LAN (`192.168.1.x`), which makes them easy to identify in firewall rules.

For why WireGuard runs on the Raspberry Pi rather than the server, see [raspberry-pi.md](raspberry-pi.md).

---

## Network information

| Service | Port | Protocol | Purpose |
|---|---|---|---|
| WireGuard | `51820` | UDP | VPN tunnel endpoint |

The router forwards UDP `51820` to the Pi (`192.168.1.50`). That is the only port exposed to the internet — everything else stays LAN/VPN-only.

The Pi's WireGuard interface (`wg0`) sits at `10.0.0.1`. VPN clients get addresses in `10.0.0.2`, `10.0.0.3`, and so on. IP forwarding on the Pi routes that VPN traffic into the actual LAN, so a connected device can reach the server, Grafana, and everything else — not just the Pi itself.

---

## Adding a new client

Each device needs its own keypair. The private key stays on the device; the public key goes into `wg0.conf` on the Pi. Never reuse keys across devices.

**Step 1 — Generate a keypair for the device**

Run this on the Pi (or any machine with `wireguard-tools` installed):

```bash
wg genkey | tee client-private.key | wg pubkey > client-public.key
cat client-private.key   # goes into the client app — keep this private
cat client-public.key    # goes into wg0.conf on the Pi
```

**Step 2 — Register the device as a peer on the Pi**

Edit `/etc/wireguard/wg0.conf` 

```
sudo nano /etc/wireguard/wg0.conf
```

and add a `[Peer]` block:

```ini
[Peer]
# Description: Pascal's phone
PublicKey = <paste client-public.key here>
AllowedIPs = 10.0.0.2/32
```

Use the next available IP for each new device. The `/32` means only that specific address is routed to this peer.

Reload WireGuard without dropping other connections:
```bash
sudo wg syncconf wg0 <(wg-quick strip wg0)
```

**What you need from the Pi before setting up any client:**
- The Pi's public key: `cat /etc/wireguard/public.key`
- The Pi's DDNS hostname and port, e.g. `yourname.duckdns.org:51820` — see [ddns-setup.md](ddns-setup.md)

---

### Phone setup (iOS and Android)

1. Install the **WireGuard** app from the App Store or Google Play.
2. Tap **+** and choose **Create from scratch**.
3. Fill in the Interface:
   - **Name:** anything (e.g. `homelab`)
   - **Private key:** paste the client private key from Step 1 above
   - **Addresses:** the IP assigned to this device (e.g. `10.0.0.2/24`)
   - **DNS:** `192.168.1.1` — lets you use hostnames like `staging.local` when connected
4. Tap **Add peer**:
   - **Public key:** the Pi's public key
   - **Endpoint:** `yourname.duckdns.org:51820`
   - **Allowed IPs:** `0.0.0.0/0` to route everything through the VPN, or `192.168.1.0/24, 10.0.0.0/24` for split tunnel (homelab traffic only)
5. Save and toggle the connection on.
6. Test: open `http://homesystem.local` or `http://192.168.1.50:3100` in a browser.

---

### Computer setup (Windows, macOS, Linux)

1. Download and install WireGuard from [wireguard.com/install](https://www.wireguard.com/install/).
2. Click **Add Tunnel** and choose **Add empty tunnel**. A keypair generates automatically — copy the public key shown and register it as a peer on the Pi before continuing.
3. Paste this config, filling in the placeholders:

```ini
[Interface]
PrivateKey = <your-client-private-key>
Address = 10.0.0.x/24
DNS = 192.168.1.1

[Peer]
PublicKey = <pi-public-key>
Endpoint = yourname.duckdns.org:51820
AllowedIPs = 192.168.1.0/24, 10.0.0.0/24
PersistentKeepalive = 25
```

4. Save and click **Activate**.
5. Test: `ping 192.168.1.30` or open `http://homesystem.local` in a browser.

`PersistentKeepalive = 25` sends a small packet every 25 seconds. This matters when connecting from behind NAT (mobile network, hotel WiFi, etc.) — without it the NAT table entry expires and the tunnel silently drops.

---

## Revoking access

Removing a device does not affect any other connected peers.

1. SSH into the Pi: `ssh homelab@192.168.1.50`
2. Open the config: `sudo nano /etc/wireguard/wg0.conf`
3. Delete the `[Peer]` block for the device being removed.
4. Reload: `sudo wg syncconf wg0 <(wg-quick strip wg0)`

The device can no longer authenticate. Its private key is now pointless since the matching public key is gone from the server.

If the device was compromised, also consider rotating the Pi's server keypair and re-registering all remaining peers with the new public key.

---

## Guest connections

A guest peer works exactly like any other peer — its own keypair, its own IP in the VPN subnet (e.g. `10.0.0.10`). If you want to restrict what a guest can reach, add `ufw` rules scoped to that specific IP rather than the whole `10.0.0.0/24` subnet. Revoking is the same process as above.

---

## Open items

- Set up DDNS before sharing the endpoint with any clients — see [ddns-setup.md](ddns-setup.md).
- Document the router port forward step — see [router-setup.md](router-setup.md).
- End-to-end test once live: disconnect from home WiFi, connect via WireGuard, confirm `staging.local`, `homesystem.local`, and Grafana all respond.