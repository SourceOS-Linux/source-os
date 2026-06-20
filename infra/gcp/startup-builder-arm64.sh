#!/usr/bin/env bash
# startup-builder-arm64.sh — GCP VM startup script for aarch64 build worker
# Runs as root on first boot on Ubuntu 22.04 ARM64.
# Nix is installed by the CI workflow on first use, not here.
set -euo pipefail

LOG="/var/log/sourceos-builder-startup.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== SourceOS ARM64 Builder Startup: $(date) ==="

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
METADATA_HEADER="Metadata-Flavor: Google"
GH_RUNNER_USER="gh-runner"
GH_RUNNER_HOME="/home/${GH_RUNNER_USER}"
GH_RUNNER_DIR="${GH_RUNNER_HOME}/actions-runner"
RUNNER_ORG="SourceOS-Linux"
RUNNER_LABELS="self-hosted,aarch64-linux,linux"

# --- System packages ---
echo "[1/4] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl git jq xz-utils tar ca-certificates sudo
echo "  Done."

# --- gh-runner user ---
echo "[2/4] Creating gh-runner user..."
id "$GH_RUNNER_USER" &>/dev/null || useradd -m -s /bin/bash "$GH_RUNNER_USER"
echo "gh-runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/gh-runner
chmod 440 /etc/sudoers.d/gh-runner
echo "  Done."

# --- GitHub Actions runner ---
echo "[3/4] Setting up GitHub Actions runner..."

GH_RUNNER_TOKEN=""
GH_RUNNER_TOKEN=$(curl -sf --connect-timeout 10 -H "$METADATA_HEADER" \
  "${METADATA_URL}/gh-runner-token" 2>/dev/null) || true

RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')
RUNNER_ARCHIVE="actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}"

if [[ ! -d "$GH_RUNNER_DIR" ]]; then
  mkdir -p "$GH_RUNNER_DIR"
  curl -fsSL "$RUNNER_URL" -o "/tmp/${RUNNER_ARCHIVE}"
  tar xzf "/tmp/${RUNNER_ARCHIVE}" -C "$GH_RUNNER_DIR"
  rm -f "/tmp/${RUNNER_ARCHIVE}"
  chown -R "${GH_RUNNER_USER}:${GH_RUNNER_USER}" "$GH_RUNNER_DIR"
  echo "  Runner v${RUNNER_VERSION} extracted."
fi

if [[ -n "$GH_RUNNER_TOKEN" ]] && [[ ! -f "$GH_RUNNER_DIR/.runner" ]]; then
  RUNNER_NAME="gcp-arm64-$(hostname)"
  sudo -u "$GH_RUNNER_USER" "$GH_RUNNER_DIR/config.sh" \
    --unattended \
    --url "https://github.com/${RUNNER_ORG}" \
    --token "$GH_RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work "_work"
  echo "  Runner configured: $RUNNER_NAME"
elif [[ -z "$GH_RUNNER_TOKEN" ]]; then
  echo "  WARNING: gh-runner-token not set in metadata — runner not configured."
fi

# --- Runner systemd service ---
echo "[4/4] Installing runner service..."
if [[ -f "$GH_RUNNER_DIR/svc.sh" ]] && [[ -f "$GH_RUNNER_DIR/.runner" ]]; then
  systemctl list-units --full -all 2>/dev/null | grep -q "actions.runner" || {
    cd "$GH_RUNNER_DIR"
    ./svc.sh install "$GH_RUNNER_USER"
    ./svc.sh start
    echo "  Runner service started."
  }
fi

echo ""
echo "=== Startup complete: $(date) ==="
echo "Runner dir: $GH_RUNNER_DIR"
