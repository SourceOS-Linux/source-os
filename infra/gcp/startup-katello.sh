#!/usr/bin/env bash
# startup-katello.sh — Native Foreman/Katello install on Rocky Linux 9
# Runs as root on first boot. Takes ~20 min.
set -euo pipefail

LOG="/var/log/sourceos-katello-startup.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== SourceOS Katello Startup: $(date) ==="

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
METADATA_HEADER="Metadata-Flavor: Google"

# --- Admin password ---
ADMIN_PASSWORD=""
if ADMIN_PASSWORD=$(curl -sf --connect-timeout 5 -H "$METADATA_HEADER" \
    "${METADATA_URL}/foreman-admin-password" 2>/dev/null) && [[ -n "$ADMIN_PASSWORD" ]]; then
  echo "  Admin password read from instance metadata."
else
  ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
  echo "$ADMIN_PASSWORD" > /root/.foreman-admin-password
  chmod 600 /root/.foreman-admin-password
  echo "  Generated random admin password → /root/.foreman-admin-password"
fi

# --- Hostname ---
echo "[1/4] Setting hostname..."
hostnamectl set-hostname katello.sourceos.internal
grep -q "katello.sourceos.internal" /etc/hosts || \
  echo "127.0.0.1  katello.sourceos.internal katello" >> /etc/hosts
echo "  Done."

# --- Repos ---
echo "[2/4] Installing Foreman/Katello repos..."
dnf install -y \
  https://yum.theforeman.org/releases/3.11/el9/x86_64/foreman-release.rpm \
  https://yum.theforeman.org/katello/4.13/katello/el9/x86_64/katello-repos-latest.rpm \
  https://yum.puppet.com/puppet7-release-el-9.noarch.rpm \
  https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# Katello requires these module streams
dnf module enable -y ruby:3.1 postgresql:13 2>/dev/null || true
dnf update -y
echo "  Repos configured."

# --- Package ---
echo "[3/4] Installing foreman-installer-katello..."
dnf install -y foreman-installer-katello
echo "  Package installed."

# --- Install ---
echo "[4/4] Running foreman-installer --scenario katello (15-20 min)..."
foreman-installer --scenario katello \
  --foreman-admin-password="${ADMIN_PASSWORD}" \
  --foreman-initial-organization="SocioProphet" \
  --foreman-initial-location="GCP" \
  --foreman-proxy-dhcp=false \
  --foreman-proxy-tftp=false \
  --foreman-proxy-dns=false \
  --enable-foreman-plugin-remote-execution \
  --enable-foreman-proxy-plugin-remote-execution-script

echo ""
echo "=== Katello installation complete: $(date) ==="
echo "  URL:      https://$(hostname -f)"
echo "  Username: admin"
if [[ -f /root/.foreman-admin-password ]]; then
  echo "  Password: $(cat /root/.foreman-admin-password)"
else
  echo "  Password: (the one set in instance metadata)"
fi
