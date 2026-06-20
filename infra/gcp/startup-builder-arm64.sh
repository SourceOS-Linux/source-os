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
RUNNER_ORG="SourceOS-Linux"
RUNNER_LABELS="self-hosted,aarch64-linux,linux"

# --- System packages ---
echo "[1/7] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl git jq xz-utils tar ca-certificates sudo

# --- Nix (official multi-user installer) ---
echo "[2/7] Installing Nix..."
if [[ -d /nix/store ]]; then
  echo "  Nix store exists, skipping install."
else
  # nixbld group/users required by multi-user install
  groupadd -r nixbld 2>/dev/null || true
  for n in $(seq 1 32); do
    useradd -r -g nixbld -d /var/empty -s /sbin/nologin -c "Nix build user $n" "nixbld${n}" 2>/dev/null || true
  done
  mkdir -p /nix
  curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon --yes
  echo "  Nix installed."
fi

# Start nix daemon
systemctl enable nix-daemon.socket nix-daemon.service 2>/dev/null || true
systemctl start nix-daemon.socket 2>/dev/null || true
systemctl start nix-daemon.service 2>/dev/null || true
sleep 5

[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && \
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

export PATH="/nix/var/nix/profiles/default/bin:${PATH}"
NIX_CMD="$(command -v nix 2>/dev/null || echo /nix/var/nix/profiles/default/bin/nix)"
[[ -x "$NIX_CMD" ]] || { echo "ERROR: nix not found. /nix:"; ls /nix/ 2>/dev/null; exit 1; }
echo "  nix: $NIX_CMD ($($NIX_CMD --version))"

# --- nix.conf ---
echo "[3/7] Configuring /etc/nix/nix.conf..."
mkdir -p /etc/nix
grep -q "extra-experimental-features" /etc/nix/nix.conf 2>/dev/null || \
  echo "extra-experimental-features = nix-command flakes" >> /etc/nix/nix.conf
systemctl restart nix-daemon.service 2>/dev/null || true
echo "  Done."

# --- cachix ---
echo "[4/7] Installing cachix..."
"$NIX_CMD" profile install nixpkgs#cachix 2>/dev/null || true
CACHIX_BIN="$(command -v cachix 2>/dev/null || true)"
[[ -n "$CACHIX_BIN" ]] && "$CACHIX_BIN" use nixos-apple-silicon 2>/dev/null || true
echo "  Done."

# --- gh-runner user ---
echo "[5/7] Creating gh-runner user..."
id "$GH_RUNNER_USER" &>/dev/null || useradd -m -s /bin/bash "$GH_RUNNER_USER"
getent group docker &>/dev/null && usermod -aG docker "$GH_RUNNER_USER" || true

# --- GitHub Actions runner ---
echo "[6/7] Setting up GitHub Actions runner..."
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
fi

if [[ -f "$GH_RUNNER_DIR/svc.sh" ]] && [[ -n "$GH_RUNNER_TOKEN" ]]; then
  systemctl list-units --full -all 2>/dev/null | grep -q "actions.runner" || {
    cd "$GH_RUNNER_DIR"
    ./svc.sh install "$GH_RUNNER_USER"
    ./svc.sh start
    echo "  Runner service started."
  }
fi

# --- SSH pubkey for Nix remote builds ---
echo "[7/7] Configuring SSH authorized keys..."
mkdir -p /root/.ssh && chmod 700 /root/.ssh
NIX_SSH_PUBKEY=$(curl -sf --connect-timeout 5 -H "$METADATA_HEADER" \
  "${METADATA_URL}/nix-ssh-pubkey" 2>/dev/null) || true
if [[ -n "$NIX_SSH_PUBKEY" ]]; then
  echo "$NIX_SSH_PUBKEY" >> /root/.ssh/authorized_keys
  sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  echo "  nix-ssh-pubkey added."
fi

echo ""
echo "=== Startup complete: $(date) ==="
