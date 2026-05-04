#!/bin/bash
# =============================================================
#  bootstrap.sh — Bootstrap a new Ubuntu Server machine
#  Run once on any new server to prepare it for the homelab.
#  Usage: bash bootstrap.sh
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

# Enable Docker to start on boot
systemctl enable docker
systemctl start docker

# Verify
docker --version
docker compose version

# =============================================================
#  4. ADD CURRENT USER TO DOCKER GROUP
#     Allows running docker without sudo
# =============================================================

section "Configuring Docker permissions"

# SUDO_USER is the user who ran sudo — i.e. the real user, not root
if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    echo "  Added $SUDO_USER to docker group."
    echo "  Note: Log out and back in for this to take effect."
fi

# =============================================================
#  5. CONFIGURE FIREWALL (UFW)
# =============================================================

section "Configuring firewall"

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

# VPN subnet — add now so it's ready when WireGuard is set up (Phase 4)
ufw allow from "$VPN_SUBNET" to any port 5001 comment "API prod from VPN"
ufw allow from "$VPN_SUBNET" to any port 5002 comment "API staging from VPN"
ufw allow from "$VPN_SUBNET" to any port 80   comment "HTTP from VPN"
ufw allow from "$VPN_SUBNET" to any port 443  comment "HTTPS from VPN"

# WireGuard port — open to internet (router forwards this externally)
ufw allow 51820/udp comment "WireGuard VPN"

# Enable firewall
ufw --force enable

# Show current rules
ufw status verbose

# =============================================================
#  6. ADD SSH PUBLIC KEY
# =============================================================

section "Configuring SSH access"

# Create .ssh directory for the real user if it doesn't exist
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
SSH_DIR="$REAL_HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Add public key if not already present
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

read -p "  Enter hostname for this machine (e.g. homelab-prod): " NEW_HOSTNAME
hostnamectl set-hostname "$NEW_HOSTNAME"
echo "  Hostname set to: $NEW_HOSTNAME"

# =============================================================
#  DONE
# =============================================================

echo
echo "  ✓ Bootstrap complete."
echo
echo "  Next steps:"
echo "    1. Log out and back in for Docker group permissions to take effect"
echo "    2. Verify Docker: docker run hello-world"
echo "    3. Verify firewall: sudo ufw status verbose"
echo "    4. Clone your repo and copy .env files to this machine"
echo