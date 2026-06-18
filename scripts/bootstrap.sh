#!/bin/bash
# =============================================================
#  bootstrap.sh — Bootstrap a new Ubuntu Server machine
#  Run once on any new server to prepare it for the homelab.
#  Usage: sudo bash bootstrap.sh
#  Safe to re-run — skips steps that are already complete.
# =============================================================

set -e  # Exit immediately if any command fails
set -u  # Treat unset variables as errors

# =============================================================
#  CONFIGURATION — edit these before running
# =============================================================

SSH_PUBLIC_KEY="ssh-ed25519 YOUR_PUBLIC_KEY_HERE your@email.com"  # TODO: paste your public key (But don't commit it to git if it's private!)
LAN_SUBNET="192.168.1.0/24"   # your home LAN
VPN_SUBNET="10.0.0.0/24"      # WireGuard VPN subnet (Phase 4)

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
    echo "  Run: sudo bash bootstrap.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

# =============================================================
#  1. SYSTEM UPDATE
# =============================================================

section "Updating system packages"

apt-get update -q
apt-get upgrade -y -q

# =============================================================
#  2. INSTALL ESSENTIALS
# =============================================================

section "Installing essential tools"

apt-get install -y -q \
    curl \
    git \
    jq \
    ufw \
    ca-certificates \
    gnupg \
    lsb-release

# =============================================================
#  3. INSTALL DOCKER
# =============================================================

section "Installing Docker"

if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
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
#     Allows running docker without sudo
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
#  4b. CREATE LOG DIRECTORIES
# =============================================================

section "Creating log directories"

mkdir -p /var/log/homelab/drink_api
chown -R "$REAL_USER:$REAL_USER" /var/log/homelab
echo "  Log directories created."

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

    # API ports — allow from LAN
    ufw allow from "$LAN_SUBNET" to any port 5001 comment "API prod from LAN"
    ufw allow from "$LAN_SUBNET" to any port 5002 comment "API staging from LAN"

    # Nginx — allow from LAN
    ufw allow from "$LAN_SUBNET" to any port 80  comment "HTTP from LAN"
    ufw allow from "$LAN_SUBNET" to any port 443 comment "HTTPS from LAN"

    # VPN subnet — ready for WireGuard (Phase 4)
    ufw allow from "$VPN_SUBNET" to any port 5001 comment "API prod from VPN"
    ufw allow from "$VPN_SUBNET" to any port 5002 comment "API staging from VPN"
    ufw allow from "$VPN_SUBNET" to any port 80   comment "HTTP from VPN"
    ufw allow from "$VPN_SUBNET" to any port 443  comment "HTTPS from VPN"

    # WireGuard port — open to internet (router forwards this externally)
    ufw allow 51820/udp comment "WireGuard VPN"

    # Enable firewall
    ufw --force enable

    echo "  Firewall configured."
else
    echo "  Firewall already active — skipping."
fi

# Always show current rules so you can verify
ufw status verbose

# =============================================================
#  6. ADD SSH PUBLIC KEY
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
#  7. CONFIGURE HOSTNAME
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
echo "    Log directories created at /var/log/homelab"
echo
echo "  Next steps:"
echo "    1. Log out and back in for Docker group permissions to take effect"
echo "    2. Verify Docker: docker run hello-world"
echo "    3. Verify firewall: sudo ufw status verbose"
echo "    4. Clone your Home_Lab repo onto this machine"
echo "    5. Copy .env.prod and .env.staging into Home_Lab/docker-compose/"
echo