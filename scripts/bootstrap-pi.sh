#!/bin/bash
# =============================================================
#  bootstrap-pi.sh — Bootstrap a new Raspberry Pi machine
#  Run once on a fresh Raspberry Pi to prepare it for the
#  homelab's VPN (WireGuard), Prometheus, and Grafana setup.
#
#  Prerequisites (do these before running this script):
#    1. Clone the Home_Lab repo onto the Pi:
#       git clone https://github.com/Alepes-8/Home_Lab.git
#    2. cd into the repo and run:
#       sudo bash scripts/bootstrap-pi.sh
#
#  Usage: sudo bash bootstrap-pi.sh
#  Safe to re-run — skips steps that are already complete.
# =============================================================

set -e  # Exit immediately if any command fails
set -u  # Treat unset variables as errors

# =============================================================
#  CONFIGURATION — edit these before running
# =============================================================

SSH_PUBLIC_KEY="ssh-ed25519 YOUR_PUBLIC_KEY_HERE your@email.com"  # TODO: paste your public key (do not commit this if the key is private)
LAN_SUBNET="192.168.1.0/24"   # Your home LAN subnet
VPN_SUBNET="10.0.0.0/24"      # WireGuard VPN subnet
PI_HOSTNAME="homelab-pi"       # Hostname for the Raspberry Pi
PI_LAN_IP="192.168.1.50"      # Static IP address for the Pi on the LAN
SERVER_LAN_IP="192.168.1.30"  # IP address of hp-z240-server — used by Prometheus scrape config
WIREGUARD_PORT="51820"         # WireGuard listen port (UDP)
WIREGUARD_IP="10.0.0.1"       # Pi's IP address on the WireGuard VPN interface

# =============================================================
#  HELPERS
# =============================================================

section() {
    echo
    echo "  ── $1 ──────────────────────────────────────────"
    echo
}

# =============================================================
#  MUST RUN AS ROOT
# =============================================================

if [[ "$EUID" -ne 0 ]]; then
    echo "  Error: This script must be run as root."
    echo "  Run: sudo bash bootstrap-pi.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

# =============================================================
#  1. SYSTEM UPDATE
# =============================================================

section "Updating system packages"

apt update -q
apt upgrade -y -q

# =============================================================
#  2. INSTALL ESSENTIALS
# =============================================================

section "Installing essential tools"

apt install -y -q \
    curl \
    git \
    jq \
    ufw \
    ca-certificates \
    gnupg \
    lsb-release \
    wireguard \
    wireguard-tools \
    iptables \
    iproute2 \
    iputils-ping \
    dnsutils \
    openresolv

# =============================================================
#  3. INSTALL DOCKER
# =============================================================

section "Installing Docker"

if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    # [arch=...] ensures the correct architecture is used (e.g. arm64 on Pi 5, amd64 on x86)
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine + Compose plugin
    apt-get update -q
    apt-get install -y -q \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    echo "  Docker installed."
else
    echo "  Docker already installed — skipping."
fi

# Enable Docker to start on boot (safe to run even if already enabled)
systemctl enable docker.socket
systemctl enable docker.service
systemctl start docker.socket
systemctl start docker.service

# Verify
docker --version
docker compose version

# =============================================================
#  4. ADD CURRENT USER TO DOCKER GROUP
#     Allows running Docker without sudo
# =============================================================

section "Configuring Docker permissions"

if ! groups "$REAL_USER" | grep -q docker; then
    usermod -aG docker "$REAL_USER"
    echo "  Added $REAL_USER to docker group."
    echo "  Note: Log out and back in for this to take effect."
else
    echo "  $REAL_USER already in docker group — skipping."
fi

# =============================================================
#  5. CONFIGURE FIREWALL (UFW)
# =============================================================

section "Configuring firewall"

if ! ufw status | grep -q "Status: active"; then
    # Reset to clean state
    ufw --force reset

    # Default policies — block everything in, allow everything out
    ufw default deny incoming
    ufw default allow outgoing

    # SSH — allow from LAN only
    ufw allow from "$LAN_SUBNET" to any port 22 comment "SSH from LAN"

    # Monitoring — allow from LAN
    ufw allow from "$LAN_SUBNET" to any port 3100 comment "Grafana from LAN"
    ufw allow from "$LAN_SUBNET" to any port 9090 comment "Prometheus from LAN"

    # Monitoring — allow from VPN subnet
    ufw allow from "$VPN_SUBNET" to any port 3100 comment "Grafana from VPN"
    ufw allow from "$VPN_SUBNET" to any port 9090 comment "Prometheus from VPN"

    # WireGuard — open to internet (router forwards UDP 51820 to this machine)
    ufw allow "$WIREGUARD_PORT"/udp comment "WireGuard VPN"

    # Enable firewall
    ufw --force enable

    echo "  Firewall configured."
else
    echo "  Firewall already active — skipping."
fi

# Always show current rules so you can verify
ufw status verbose

# =============================================================
#  6. CONFIGURE WIREGUARD SERVER
# =============================================================

section "Configuring WireGuard"

if ! command -v wg &> /dev/null; then
    echo "  Error: WireGuard not found — was it installed in Section 2?"
    exit 1
fi

if [[ -f /etc/wireguard/wg0.conf ]]; then
    echo "  WireGuard already configured — skipping."
else
    # Generate server keypair and store securely
    # Pipes private key through wg pubkey to derive the public key in one step
    wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
    chmod 600 /etc/wireguard/private.key

    # Detect the Pi's LAN-facing network interface dynamically
    # (typically eth0 on Pi, but this avoids hardcoding)
    LAN_INTERFACE=$(ip route | grep default | awk '{print $5}')

    # Write wg0.conf — the WireGuard server interface config
    # PostUp/PostDown: iptables rules that forward VPN traffic into the LAN
    # and masquerade it so return traffic routes back correctly
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = $WIREGUARD_IP/24
PrivateKey = $(cat /etc/wireguard/private.key)
ListenPort = $WIREGUARD_PORT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $LAN_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $LAN_INTERFACE -j MASQUERADE

# Peers are added here after running docs/wireguard-clients.md setup
# Example:
# [Peer]
# PublicKey = <client-public-key>
# AllowedIPs = 10.0.0.2/32
EOF

    chmod 600 /etc/wireguard/wg0.conf

    # Enable IP forwarding so VPN traffic can be routed into the LAN
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    fi
    sysctl -p

    # Enable WireGuard to start on boot, then bring the interface up now
    systemctl enable wg-quick@wg0

    if ! wg show wg0 &> /dev/null; then
        wg-quick up wg0
    fi

    echo "  WireGuard configuration complete."
    echo "  Pi public key (share this with VPN clients):"
    cat /etc/wireguard/public.key
fi

# =============================================================
#  7. ADD SSH PUBLIC KEY
# =============================================================

section "Configuring SSH access"

SSH_DIR="$REAL_HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if ! grep -qF "$SSH_PUBLIC_KEY" "$SSH_DIR/authorized_keys" 2>/dev/null; then
    echo "$SSH_PUBLIC_KEY" >> "$SSH_DIR/authorized_keys"
    echo "  SSH public key added."
else
    echo "  SSH public key already present — skipping."
fi

chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$REAL_USER:$REAL_USER" "$SSH_DIR"

# =============================================================
#  8. CONFIGURE HOSTNAME
# =============================================================

section "Setting hostname"

CURRENT_HOSTNAME=$(hostname)
echo "  Current hostname: $CURRENT_HOSTNAME"
read -p "  Enter new hostname (leave blank to keep current): " NEW_HOSTNAME

if [[ -n "$NEW_HOSTNAME" && "$NEW_HOSTNAME" != "$CURRENT_HOSTNAME" ]]; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "  Hostname set to: $NEW_HOSTNAME"
else
    echo "  Hostname unchanged — skipping."
fi

# =============================================================
#  DONE
# =============================================================

echo
echo "  ✓ Bootstrap complete."
echo
echo "  Next steps:"
echo
echo "    1. Complete router setup — see docs/router-setup.md"
echo "       - Reserve $PI_LAN_IP for this Pi's MAC address (DHCP reservation)"
echo "       - Forward UDP $WIREGUARD_PORT → $PI_LAN_IP (WireGuard port forward)"
echo
echo "    2. Set up DDNS — see docs/ddns-setup.md"
echo "       - Gives WireGuard a stable hostname even when your home IP changes"
echo
echo "    3. Log out and back in for Docker group permissions to take effect"
echo "       - Verify: docker run hello-world"
echo
echo "    4. Verify firewall: sudo ufw status verbose"
echo
echo "    5. Set up WireGuard clients — see docs/wireguard-clients.md"
echo "       - Generate a keypair per client device (laptop, phone)"
echo "       - Add each client's public key as a [Peer] entry in /etc/wireguard/wg0.conf"
echo "       - Install WireGuard client app on each device and configure"
echo "       - Reload WireGuard: sudo wg-quick down wg0 && sudo wg-quick up wg0"
echo
echo "    6. Run the monitoring stack:"
echo "       docker compose -f docker-compose/docker-compose.monitoring.yml up -d"
echo
echo "    7. Add /metrics location block to nginx on the old PC"
echo "       - See nginx/sites/homesystem.local.conf"
echo "       - Allows Prometheus on the Pi to scrape metrics through nginx port 80"
echo
echo "    8. Verify services are reachable:"
echo "       - Grafana:    http://$PI_LAN_IP:3100"
echo "       - Prometheus: http://$PI_LAN_IP:9090"
echo "       - WireGuard:  sudo wg show"
echo
echo "    9. Test VPN end-to-end:"
echo "       - Disconnect from home WiFi"
echo "       - Connect via WireGuard client"
echo "       - Verify staging.local, homesystem.local, and Grafana all respond correctly"
echo