# Router Setup

This covers the two router-level changes needed for the homelab to work correctly: giving the Pi and server fixed IP addresses (DHCP reservations), and forwarding the WireGuard port to the Pi so it is reachable from the internet.

The exact UI varies between router models, but the steps are the same regardless of brand. Look for similar labels if yours differs from what is described here.

---

## Static IP addresses (DHCP reservation)

By default, routers hand out IP addresses dynamically — the same device might get a different address after a reboot. A DHCP reservation ties a specific IP to a specific device's MAC address permanently, so `192.168.1.30` always means the server and `192.168.1.50` always means the Pi.

**Finding the MAC address:**

On the server or Pi, run:
```bash
ip a
```
Look for the ethernet interface (usually `eth0`, `eno1`, or similar). The MAC address appears as `link/ether xx:xx:xx:xx:xx:xx`.

Alternatively, once the device is connected, most routers show currently connected devices with their MAC addresses in the DHCP client list — you can find and select the device from there instead.

**Creating the reservation:**

1. Access your router at `http://192.168.1.1` in a browser.
2. Log in with your router credentials.
3. Find **DHCP reservations**, **static leases**, or **address reservations** — the label varies by router.
4. Add a new entry:
   - **MAC address:** the value from `ip a` above
   - **IP address:** `192.168.1.30` for the server, `192.168.1.50` for the Pi
5. Save and reboot the device to confirm it picks up the reserved address.

Do this for both the server and the Pi.

---

## Port forwarding — WireGuard (UDP 51820)

For WireGuard to be reachable from outside the home network, the router needs to forward incoming UDP traffic on port `51820` to the Pi. Without this, WireGuard is only accessible from inside the LAN.

**Steps:**

1. Access your router at `http://192.168.1.1`.
2. Log in.
3. Find **port forwarding**, **virtual server**, or **NAT** — again, label varies by router.
4. Add a new rule:
   - **External port:** `51820`
   - **Protocol:** `UDP`
   - **Internal IP:** `192.168.1.50` (the Pi)
   - **Internal port:** `51820`
5. Save.

You can verify this is working from outside the network once WireGuard is running on the Pi. From inside the LAN it will always be reachable regardless of port forwarding.

**Note:** this is the only port ever forwarded externally. Everything else (nginx on port 80, Grafana on 3100, the APIs on 5001/5002) stays LAN/VPN-only.

---

## After these steps

Once both reservations and the port forward are done:

- Continue with [raspberry-pi.md](raspberry-pi.md) setup
- Set up DDNS so WireGuard clients have a stable hostname to connect to — see [ddns-setup.md](ddns-setup.md)
- Configure WireGuard clients on your devices — see [wireguard.md](wireguard.md)