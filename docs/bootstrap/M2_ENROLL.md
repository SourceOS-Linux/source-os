# SourceOS M2 Enrollment Runbook

Canonical procedure for taking any Apple Silicon M2 from bare metal to a fully
enrolled SourceOS builder node. After completing this runbook the device will:

- Boot into NixOS on Asahi Linux
- Run a local Foreman+Katello content lifecycle stack (Docker, linux/amd64 via qemu)
- Have `sourceos-syncd` polling the local Katello `stable` env every 5 minutes
- Auto-apply NixOS updates and emit `SyncCycleReceipt` evidence on each cycle
- Auto-rollback via `sourceos-boot` if the post-boot health check fails

---

## Prerequisites

| Item | Notes |
|------|-------|
| M2 Mac (any model) | MacBook Pro/Air M2, Mac Mini M2, Mac Studio M2 |
| 8 GB RAM minimum | 16 GB recommended (Foreman+Katello uses ~3 GB) |
| 100 GB free disk | NixOS partition + Docker volumes |
| Internet connection | Required for Asahi installer + Nix binary cache |
| macOS 13.0+ | Asahi installer requires Ventura or later |

---

## Phase A — Install Asahi Linux

> **Duration: ~20 min**

1. Open Terminal on macOS and run the Asahi installer:
   ```sh
   curl https://alx.sh | sh
   ```
2. Select **"Asahi Linux (minimal)"** — this gives you a minimal Fedora Asahi base. We replace it with NixOS in Phase B.
3. Follow the on-screen instructions. The installer will resize the macOS partition, reboot into a recovery environment, and then reboot again into the new Linux partition.
4. After the first Linux boot you'll have a minimal Fedora Asahi shell.

---

## Phase B — Install NixOS on the Asahi Partition

> **Duration: ~15 min**

This replaces the Fedora Asahi base with NixOS using the nixos-infect method.

1. In the Fedora Asahi shell, become root:
   ```sh
   sudo -i
   ```

2. Download and run nixos-infect:
   ```sh
   curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
     NIX_CHANNEL=nixos-unstable \
     NO_REBOOT=1 \
     bash 2>&1 | tee /tmp/nixos-infect.log
   ```
   > `NO_REBOOT=1` keeps you in the session so you can clone source-os before rebooting.

3. Clone source-os into place:
   ```sh
   mkdir -p /opt/sourceos
   git clone https://github.com/SociOS-Linux/source-os.git /opt/sourceos/source-os
   ```

4. Set `SOURCEOS_REPO_ROOT` and `PROPHET_PLATFORM_ROOT` for the enrollment script:
   ```sh
   export SOURCEOS_REPO_ROOT=/opt/sourceos/source-os
   export PROPHET_PLATFORM_ROOT=/opt/prophet-platform
   ```

5. Reboot into NixOS:
   ```sh
   reboot
   ```

---

## Phase C — First NixOS Boot

After reboot you'll be in the NixOS Asahi base system. Log in as root (no password yet) or use the console.

1. Verify you're on NixOS:
   ```sh
   nixos-version
   ```

2. Verify the Asahi kernel is active:
   ```sh
   uname -r   # should end in -asahi or similar
   ```

---

## Phase D — Run Enrollment Script

> **Duration: ~30–45 min (mostly Foreman installer)**

The enrollment script is fully automated. Run it once from the source-os repo:

```sh
cd /opt/sourceos/source-os
sudo SOURCEOS_REPO_ROOT=$PWD bash scripts/enroll.sh
```

### What the script does (step by step)

| Step | Action |
|------|--------|
| 0 | Preflight checks (root, NixOS, repo present) |
| 1 | `nixos-generate-config` → `hosts/builder-aarch64/hardware-configuration.nix` |
| 2 | `nixos-rebuild switch` pass 1 — installs Docker, age, sops, minisign |
| 3 | Generate device age key at `/etc/sourceos/age.key` |
| 4 | Clone prophet-platform, generate random admin passwords, `docker compose up` Foreman+Katello |
| 5 | Run `scripts/katello-sourceos-setup.sh` — creates org, product, repos, content view |
| 6 | Encrypt Katello password with SOPS → `/etc/sourceos/secrets.yaml` |
| 7 | `nix build` the `builder-aarch64` closure + `nix copy` it to the local Katello Nix cache |
| 8 | Promote content view `dev → candidate → stable` |
| 9 | Generate minisign key pair at `/etc/sourceos/nix-cache.{pub,sec}` |
| 10 | Patch `signingPublicKey` into `hosts/builder-aarch64/default.nix` |
| 11 | `nixos-rebuild switch` pass 2 — live config with secrets + signing verification |
| 12 | Verify `sourceos-syncd` is running + emitted first receipt |

### Monitoring the Foreman installer (step 4)

In a separate terminal:
```sh
docker compose -f /opt/prophet-platform/infra/local/docker-compose.foreman-katello.yml \
  logs -f foreman-katello
```

The installer completes when you see `Installation complete!`. The enrollment script waits automatically.

---

## Phase E — Post-Enrollment Verification

After the script prints the success banner:

```sh
# Daemon running?
systemctl status sourceos-syncd

# First poll log
journalctl -u sourceos-syncd -n 50

# Last sync receipt
sourceos-syncd receipts last

# Health check
sourceos-syncd sync check-health
```

Expected first-run output from `receipts last`:
```json
{
  "outcome": "applied",
  "locus": "local",
  "lifecycleEnv": "stable",
  "contentView": "sourceos-builder-aarch64"
}
```

---

## Steady-State Operation

Once enrolled, the device is self-managing:

```
Every 5 min:  sourceos-syncd polls Katello stable
              → if new content view version: nix copy → nixos-rebuild → emit SyncCycleReceipt
              → if no change: emit SyncCycleReceipt (outcome: no_change)

120s post-boot: sourceos-health-check.timer fires
              → if healthy: no action
              → if unhealthy: sourceos-boot rollback execute → nixos-rebuild --rollback
```

To trigger an update manually:
```sh
# Promote a new version to stable in Katello, then force a poll:
systemctl restart sourceos-syncd
```

---

## Credentials and Secrets

| Secret | Location | Notes |
|--------|----------|-------|
| Device age key | `/etc/sourceos/age.key` | Never leaves the device |
| SOPS-encrypted secrets | `/etc/sourceos/secrets.yaml` | Encrypted with device age key |
| Katello admin password | `/etc/sourceos/katello-admin-password` | Generated by enroll.sh |
| Katello UI | `https://127.0.0.1:8443` | admin / see katello-admin-password |
| minisign private key | `/etc/sourceos/nix-cache.sec` | Guards Nix cache integrity |
| minisign public key | `/etc/sourceos/nix-cache.pub` | Embedded in NixOS config as `signingPublicKey` |

---

## Re-enrollment / Recovery

If the device needs to be re-enrolled (e.g., after disk wipe):

1. Repeat Phase A–C.
2. The enrollment script is idempotent — run it again.
3. If Docker volumes are lost, Foreman+Katello will re-initialize (re-run `katello-sourceos-setup.sh` inside the script).
4. A new age key will be generated; re-encrypt secrets with the new key.

---

## Troubleshooting

### `nixos-rebuild` fails with "file not found: hardware-configuration.nix"
Run `nixos-generate-config --show-hardware-config > hosts/builder-aarch64/hardware-configuration.nix` manually, then re-run `nixos-rebuild`.

### Foreman installer never completes
```sh
docker exec katello-foreman tail -f /var/log/foreman-installer/foreman-installer.log
```
If it hangs on `Puppet:`: restart the container and try again (`docker compose restart foreman-katello`).

### `sourceos-syncd` fails with "certificate verify failed"
The local Foreman uses a self-signed cert. The `noVerifySsl = true` option in `hosts/builder-aarch64/default.nix` handles this. If you changed it, revert.

### `nix copy` fails
Pulp content endpoint may not be ready. Check: `curl -v http://127.0.0.1:8101/v3/status/`. If the endpoint is missing, the Foreman installer is still running.

### Rollback triggered unexpectedly
```sh
sourceos-syncd receipts list   # see recent receipts
journalctl -u sourceos-health-check -n 50
sourceos-boot rollback plan    # dry-run the rollback plan
```
