#!/bin/sh

echo "This script will install and start Docker. After running it you should install"
echo "individual applications by running 'docker compose up -d' in each application's"
echo "directory, or run an install script for a stack of applications."
echo
echo "This script uses sudo to run items as root; you'll be prompted at least once at"
echo "the start to enter your password in order to allow this"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DATA_ROOT="$REPO_ROOT/docker-lib"

sudo apt update && sudo apt upgrade -y
sudo apt install -y pwgen curl software-properties-common emacs-nox git neovim bash-completion tmux vim-nox wget

if ! command -v docker > /dev/null 2>&1; then
    echo "Docker not found. Installing Docker..."

    sudo apt install -y apt-transport-https ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo sh -c ". /etc/os-release && echo \
        \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/debian \$VERSION_CODENAME stable\"" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli

    sudo systemctl start docker
    sudo systemctl enable docker

    if command -v docker > /dev/null 2>&1; then
        echo "Docker installed successfully."
    else
        echo "Docker installation failed."
        exit 1
    fi
else
    echo "Docker is already installed."
fi

# ── Docker daemon configuration ──────────────────────────────────────────────
echo "Configuring Docker daemon..."

sudo mkdir -p /etc/docker
sudo mkdir -p "$DOCKER_DATA_ROOT"

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}",

  "default-address-pools": [
    { "base": "172.17.0.0/12", "size": 24 }
  ],

  "log-driver": "journald",
  "log-opts": {
    "tag": "docker/{{.Name}}"
  }
}
EOF

echo "Docker daemon configured (data-root: $DOCKER_DATA_ROOT)."

# ── Kernel: enable memory overcommit (required for Redis) ────────────────────
echo "Configuring vm.overcommit_memory for Redis..."

sudo tee /etc/sysctl.d/60-redis.conf > /dev/null <<'EOF'
# Allow memory overcommit so Redis background saves and replication don't fail
# under low-memory conditions. Required by Redis (and jemalloc).
# See: https://github.com/jemalloc/jemalloc/issues/1328
vm.overcommit_memory = 1
EOF

sudo sysctl -q -p /etc/sysctl.d/60-redis.conf
echo "vm.overcommit_memory=1 applied."

# ── journald: volatile (in-memory) storage capped at 256 MB ──────────────────
echo "Configuring journald for in-memory Docker logging..."

sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/50-docker.conf > /dev/null <<'EOF'
[Journal]
# Keep all logs in RAM only - avoids SSD write amplification.
# Logs are lost on reboot; use 'journalctl -u docker' or
# 'journalctl CONTAINER_NAME=<name>' to view them while running.
Storage=volatile
RuntimeMaxUse=256M
EOF

sudo systemctl restart systemd-journald
echo "journald configured (volatile, 256 MB cap)."

# ── Restart Docker to apply new daemon config ─────────────────────────────────
sudo systemctl restart docker
echo "Docker restarted."

# ── Nightly docker system prune cron job ─────────────────────────────────────
echo "Installing nightly docker prune cron job..."

sudo tee /etc/cron.d/docker-prune > /dev/null <<'EOF'
# Remove stopped containers, dangling images, unused networks and build cache.
# Volumes are intentionally excluded to protect persistent data.
0 3 * * * root docker system prune -f >> /var/log/docker-prune.log 2>&1
EOF

sudo chmod 644 /etc/cron.d/docker-prune
echo "Cron job installed (/etc/cron.d/docker-prune, runs at 03:00 daily)."
