# Setup

This document walks through setting up the homelab from scratch. It is split into sections based on where you are in the process — whether you are starting from a bare machine with no OS, or picking up from a point where the server is already running Ubuntu.

The steps are written for Ubuntu 24.04.4 LTS. Other versions will mostly work the same, but some details may differ.

---

## Server setup

### Installing Ubuntu

**What you need before starting:**
- A machine to use as the server (old PC, laptop, workstation, anything that can run headless)
- A monitor and keyboard plugged into that machine
- An ethernet connection
- An empty USB stick (8GB or larger)

**Steps:**

1. On your development machine (not the server), go to [ubuntu.com/download/server](https://ubuntu.com/download/server) and download the latest LTS release.
2. Download and open [balenaEtcher](https://etcher.balena.io/). Select the Ubuntu ISO you just downloaded, select the USB stick as the destination, and flash it.
3. Once done, unplug the USB from your dev machine and plug it into the server.
4. Boot the server from the USB. If you need to select a boot device, look for a boot menu key during startup (usually F12, F10, or Del depending on the motherboard). Choose the USB drive. If you see multiple EFI options, select `bootx64.efi`.
5. Work through the Ubuntu installer. A few things to pay attention to:
   - **Network:** set the interface to `eno1` or `eno0`, with both IPv4 and IPv6 configured.
   - **Credentials:** note your username, password, and server name — you will need them to SSH in later. The difference: your name is cosmetic only, the username is what you type in `ssh username@192.168.1.x`, and the server name is what the machine calls itself on the network.
   - **OpenSSH Server:** when this option appears, install it. Do not skip this.
   - Everything else can be left at defaults or skipped. Leave VLAN blank, no proxy, no encryption, skip Ubuntu Pro, do not import snaps.

### Core server setup

Once Ubuntu is installed:

1. Follow [access-server.md](access-server.md) to configure a static IP and connect via SSH.
2. Once connected, update the system and install Docker:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install docker.io -y
   sudo usermod -aG docker $USER
   exit
   ```
3. SSH back in and verify Docker is working:
   ```bash
   docker run hello-world
   ```

---

## Server project setup

1. **On your development machine**, clone the `Home_Lab` repo and do the following prep work before touching the server:

   - Get your SSH public key for `bootstrap.sh`:
     ```bash
     cat ~/.ssh/id_ed25519.pub
     ```
     If you do not have one yet:
     ```bash
     ssh-keygen -t ed25519 -C "your@email.com"
     ```
     This creates `~/.ssh/id_ed25519` (private key, never share this) and `~/.ssh/id_ed25519.pub` (public key, this is what you share). Copy the full string from the `.pub` file and paste it into `bootstrap.sh` where it says `TODO`.

   - Create `.env.prod` and `.env.staging` in the `docker-compose/` folder. Make sure `MONGO_URI` points to the container name, not localhost:
     ```
     MONGO_URI=mongodb://mongo-prod-database:27017/drink   # for prod
     MONGO_URI=mongodb://mongo-staging-database:27017/drink  # for staging
     ```

2. **Get `bootstrap.sh` onto the server.** Pick whichever method is easiest:

   - Copy from your local machine:
     ```bash
     scp scripts/bootstrap.sh homelab@192.168.1.30:~/bootstrap.sh
     ```
   - Paste it manually over SSH:
     ```bash
     ssh homelab@192.168.1.30
     nano bootstrap.sh
     # paste the contents, Ctrl+X to save
     ```
   - Pull directly from GitHub (only works if the repo is public):
     ```bash
     curl -o bootstrap.sh https://raw.githubusercontent.com/Alepes-8/Home_Lab/main/scripts/bootstrap.sh
     ```

3. SSH into the server and run the bootstrap script. It installs Docker, configures the firewall, and adds your SSH key:
   ```bash
   sudo bash bootstrap.sh
   ```
   If it asks whether to automatically restart the Docker daemon, say yes.

4. Clone the `Home_Lab` repo onto the server:
   ```bash
   git clone https://github.com/Alepes-8/Home_Lab.git
   ```

5. Copy the `.env` files to the server. Since they are gitignored, they have to be transferred separately:
   ```bash
   scp /path/to/Home_Lab/docker-compose/.env.prod homelab@192.168.1.30:~/Home_Lab/docker-compose/.env.prod
   scp /path/to/Home_Lab/docker-compose/.env.staging homelab@192.168.1.30:~/Home_Lab/docker-compose/.env.staging
   ```

6. Work through the next steps printed at the end of `bootstrap.sh`.

7. Create the shared Docker network:
   ```bash
   docker network create homelab-network
   ```

8. Create the log directory for the API:
   ```bash
   sudo mkdir -p /var/log/homelab/drink_api
   sudo chmod 777 /var/log/homelab/drink_api
   ```

9. Authenticate with GHCR so the server can pull images:
   ```bash
   echo YOUR_PAT | docker login ghcr.io -u Alepes-8 --password-stdin
   ```
   Replace `YOUR_PAT` with a personal access token that has `read:packages` scope. If you need to create one, go to [github.com/settings/tokens](https://github.com/settings/tokens).

   Also add the token to `~/.bashrc` so the rollback script can use it:
   ```bash
   echo 'export GHCR_USER="Alepes-8"' >> ~/.bashrc
   echo 'export GHCR_PAT="your-token-here"' >> ~/.bashrc
   source ~/.bashrc
   ```

10. Start the staging stack:
    ```bash
    cd ~/Home_Lab/docker-compose
    docker compose -f docker-compose.staging.yml up -d
    ```

11. Verify it is running:
    ```bash
    curl http://localhost:5002/drink/health
    ```
    You should see a JSON response with `"mongoStatus": "MongoDB reachable"`.

12. Start the prod stack and nginx the same way:
    ```bash
    docker compose -f docker-compose.prod.yml up -d
    docker compose -f docker-compose.nginx.yml up -d
    ```

13. Once the server is running, move on to the Raspberry Pi — see [raspberry-pi.md](raspberry-pi.md).