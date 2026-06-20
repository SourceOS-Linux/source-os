#!/usr/bin/env bash
# startup-builder-arm64.sh — GCP VM startup script for aarch64 build worker
# Runs as root on first boot on Ubuntu 22.04 ARM64
set -euo pipefail

LOG="/var/log/sourceos-builder-startup.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== SourceOS ARM64 Builder Startup: $(date) ==="

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
METADATA_HEADER="Metadata-Flavor: Google"
GH_RUNNER_USER="gh-runner"
GH_RUNNER_HOME="/home/${GH_RUNNER_USER}"
GH_RUNNER_DIR="${GH_RUNNER_HOME}/actions-runner"
RUNNER_ORG="SociOS-Linux"
RUNNER_LABELS="self-hosted,aarch64-linux,linux"

# --- System packages ---
echo "[1/7] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  curl \
  git \
  jq \
  xz-utils \
  tar \
  ca-certificates \
  sudo

# --- Nix (Determinate Systems) ---
echo "[2/7] Installing Nix via Determinate Systems installer..."
if [ -f /nix/receipt.json ] || command -v nix &>/dev/null; then
  echo "  Nix already installed, skipping."
else
  curl -sSf https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  echo "  Nix installed."
fi

# Source nix profile for remainder of script
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck source=/dev/null
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Determinate Systems installs nix here; ensure it's on PATH regardless of sourcing
export PATH="/nix/var/nix/profiles/default/bin:${PATH}"
NIX_CMD="/nix/var/nix/profiles/default/bin/nix"
[[ -x "$NIX_CMD" ]] || { echo "ERROR: nix binary not found at $NIX_CMD"; exit 1; }

# --- nix.conf ---
echo "[3/7] Configuring /etc/nix/nix.conf..."
mkdir -p /etc/nix
if grep -q "extra-experimental-features" /etc/nix/nix.conf 2>/dev/null; then
  echo "  experimental-features already configured."
else
  cat >> /etc/nix/nix.conf <<NIX_CONF
extra-experimental-features = nix-command flakes
NIX_CONF
  echo "  Added experimental-features."
fi

# Restart nix-daemon to pick up config
systemctl restart nix-daemon.service 2>/dev/null || true

# --- cachix ---
echo "[4/7] Installing cachix and configuring nixos-apple-silicon cache..."
"$NIX_CMD" profile install nixpkgs#cachix 2>/dev/null || \
  "$NIX_CMD" --extra-experimental-features "nix-command flakes" \
    profile install nixpkgs#cachix

CACHIX_BIN="$(command -v cachix || /root/.nix-profile/bin/cachix || true)"
if [ -n "$CACHIX_BIN" ]; then
  "$CACHIX_BIN" use nixos-apple-silicon || true
  echo "  cachix nixos-apple-silicon configured."
else
  echo "  WARNING: cachix binary not found, skipping cache setup."
fi

# --- gh-runner user ---
echo "[5/7] Creating gh-runner user..."
if id "$GH_RUNNER_USER" &>/dev/null; then
  echo "  User $GH_RUNNER_USER already exists."
else
  useradd -m -s /bin/bash "$GH_RUNNER_USER"
  echo "  Created user $GH_RUNNER_USER."
fi

# Allow gh-runner to use docker if available
if getent group docker &>/dev/null; then
  usermod -aG docker "$GH_RUNNER_USER" || true
fi

# --- GitHub Actions runner ---
echo "[6/7] Setting up GitHub Actions runner..."

# Read runner token from GCP metadata
GH_RUNNER_TOKEN=""
if GH_RUNNER_TOKEN=$(curl -sf \
    --connect-timeout 10 \
    -H "$METADATA_HEADER" \
    "${METADATA_URL}/gh-runner-token" 2>/dev/null); then
  echo "  Runner token read from metadata."
else
  echo "  WARNING: gh-runner-token metadata not set. Runner will not be configured."
  GH_RUNNER_TOKEN=""
fi

# Determine latest runner release for arm64
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')
RUNNER_ARCHIVE="actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}"

if [ ! -d "$GH_RUNNER_DIR" ]; then
  mkdir -p "$GH_RUNNER_DIR"
  echo "  Downloading runner v${RUNNER_VERSION}..."
  curl -fsSL "$RUNNER_URL" -o "/tmp/${RUNNER_ARCHIVE}"
  tar xzf "/tmp/${RUNNER_ARCHIVE}" -C "$GH_RUNNER_DIR"
  rm -f "/tmp/${RUNNER_ARCHIVE}"
  chown -R "${GH_RUNNER_USER}:${GH_RUNNER_USER}" "$GH_RUNNER_DIR"
  echo "  Runner extracted to $GH_RUNNER_DIR."
else
  echo "  Runner directory already exists, skipping download."
fi

# Configure runner if token is available and runner not already configured
if [ -n "$GH_RUNNER_TOKEN" ] && [ ! -f "$GH_RUNNER_DIR/.runner" ]; then
  RUNNER_NAME="gcp-arm64-$(hostname)"
  sudo -u "$GH_RUNNER_USER" \
    "$GH_RUNNER_DIR/config.sh" \
      --unattended \
      --url "https://github.com/${RUNNER_ORG}" \
      --token "$GH_RUNNER_TOKEN" \
      --name "$RUNNER_NAME" \
      --labels "$RUNNER_LABELS" \
      --work "_work"
  echo "  Runner configured: $RUNNER_NAME"
elif [ -f "$GH_RUNNER_DIR/.runner" ]; then
  echo "  Runner already configured."
fi

# Install and start runner as systemd service
if [ -f "$GH_RUNNER_DIR/svc.sh" ] && [ -n "$GH_RUNNER_TOKEN" ]; then
  if ! systemctl list-units --full -all 2>/dev/null | grep -q "actions.runner"; then
    cd "$GH_RUNNER_DIR"
    ./svc.sh install "$GH_RUNNER_USER"
    ./svc.sh start
    echo "  Runner systemd service installed and started."
  else
    echo "  Runner service already installed."
  fi
fi

# --- SSH pubkey for Nix remote builds ---
echo "[7/7] Configuring SSH authorized keys..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

NIX_SSH_PUBKEY=""
if NIX_SSH_PUBKEY=$(curl -sf \
    --connect-timeout 5 \
    -H "$METADATA_HEADER" \
    "${METADATA_URL}/nix-ssh-pubkey" 2>/dev/null); then
  echo "$NIX_SSH_PUBKEY" >> /root/.ssh/authorized_keys
  sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  echo "  nix-ssh-pubkey added to /root/.ssh/authorized_keys."
else
  echo "  No nix-ssh-pubkey metadata found, skipping."
fi

echo ""
echo "=== Startup complete: $(date) ==="
echo "Runner status: sudo -u $GH_RUNNER_USER $GH_RUNNER_DIR/svc.sh status"
echo "Runner logs  : journalctl -u actions.runner.* -f"
