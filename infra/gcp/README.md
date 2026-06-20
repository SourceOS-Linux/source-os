# SourceOS GCP Build Infrastructure

## Scripts

**`provision-katello.sh`**
Creates the Foreman/Katello server VM (`sourceos-katello`, `n2-standard-8`, `us-central1-a`, 100 GB SSD). Reserves a static external IP (`sourceos-katello-ip`), adds a firewall rule allowing inbound TCP 443, and attaches the `startup-katello.sh` startup script.

**`startup-katello.sh`**
Runs as root on first boot. Installs Docker + Docker Compose v2, clones `prophet-platform`, stages the Katello docker-compose working directory at `/opt/sourceos-katello/`, reads or generates the Foreman admin password, writes `/opt/sourceos-katello/.env`, patches port bindings for public access, starts Katello via `docker compose up -d`, and installs a `sourceos-katello.service` systemd unit for persistence across reboots. All output is logged to `/var/log/sourceos-katello-startup.log`.

**`provision-builder-arm64.sh`**
Creates the aarch64 build worker VM (`sourceos-builder-arm64`, `t2a-standard-16`, `us-central1-b`, 200 GB SSD, Ubuntu 22.04 ARM64). Adds a firewall rule allowing inbound SSH on tag `sourceos-builder` and attaches the `startup-builder-arm64.sh` startup script.

**`startup-builder-arm64.sh`**
Runs as root on first boot. Installs Nix via the Determinate Systems installer, sets `extra-experimental-features = nix-command flakes` in `/etc/nix/nix.conf`, installs cachix and configures the `nixos-apple-silicon` binary cache, creates the `gh-runner` system user, downloads the latest GitHub Actions runner for `arm64`, configures it against the `SourceOS-Linux` org with labels `self-hosted,aarch64-linux,linux` using the token from instance metadata, installs the runner as a systemd service, and adds the Nix SSH pubkey from metadata to `/root/.ssh/authorized_keys`. All output is logged to `/var/log/sourceos-builder-startup.log`.

---

## How to Run

```bash
# Provision Foreman/Katello server
bash infra/gcp/provision-katello.sh

# Provision ARM64 build worker
bash infra/gcp/provision-builder-arm64.sh
```

Both scripts are idempotent — re-running skips resources that already exist.

---

## Setting Metadata

**Foreman admin password** (set before or shortly after provisioning; startup script reads it on first boot):
```bash
gcloud compute instances add-metadata sourceos-katello \
  --zone=us-central1-a \
  --metadata foreman-admin-password=<your-password>
```

**GitHub Actions runner token** (generate at `https://github.com/organizations/SourceOS-Linux/settings/actions/runners/new`):
```bash
gcloud compute instances add-metadata sourceos-builder-arm64 \
  --zone=us-central1-b \
  --metadata gh-runner-token=<token>
```

**Nix remote-build SSH pubkey** (optional, for nix remote builds over SSH):
```bash
gcloud compute instances add-metadata sourceos-builder-arm64 \
  --zone=us-central1-b \
  --metadata nix-ssh-pubkey="ssh-ed25519 AAAA..."
```

---

## Retrieving the Auto-Generated Foreman Password

If `foreman-admin-password` metadata was not set before the startup script ran, a random password was generated and saved on the VM:

```bash
gcloud compute ssh sourceos-katello --zone=us-central1-a -- \
  cat /opt/sourceos-katello/.admin-password
```

---

## Running the Katello Setup Script

After Katello is up and healthy (allow ~5 minutes for containers to start):

```bash
FOREMAN_URL=https://<EXTERNAL_IP> \
FOREMAN_PASSWORD=<admin-password> \
bash scripts/katello-sourceos-setup.sh
```

Replace `<EXTERNAL_IP>` with the static IP printed by `provision-katello.sh` (also visible via `gcloud compute addresses describe sourceos-katello-ip --region=us-central1`).

---

## Post-Provisioning Checklist

- [ ] Katello containers are healthy: `gcloud compute ssh sourceos-katello --zone=us-central1-a -- docker compose -f /opt/sourceos-katello/docker-compose.yml ps`
- [ ] Foreman UI accessible at `https://<EXTERNAL_IP>` (may take several minutes for first-run initialization)
- [ ] `katello-sourceos-setup.sh` completed successfully
- [ ] ARM64 runner visible in GitHub: `https://github.com/organizations/SourceOS-Linux/settings/actions/runners`
- [ ] Nix remote build SSH access verified (if using distributed builds): `ssh root@<builder-ip> nix store info`
- [ ] `nixos-apple-silicon` cache hit confirmed on a test build
