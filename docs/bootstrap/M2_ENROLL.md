# SourceOS M2 Enrollment Runbook

Canonical procedure for enrolling any Apple Silicon M2 as a SourceOS builder node.

After completion the device runs:
- NixOS on Asahi Linux (bare-metal aarch64)
- Foreman+Katello content lifecycle stack (Docker, linux/amd64 via qemu-user-static)
- `harmonia` Nix binary cache at `http://127.0.0.1:8101` (nginx proxy + minisig endpoint)
- `sourceos-syncd` polling Katello `stable` every 5 min, applying NixOS updates, emitting `SyncCycleReceipt`
- `sourceos-boot` health-check timer auto-rolling back failed updates

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| M2 Mac (any model) | MacBook Pro/Air/Mini/Studio M2 |
| 16 GB RAM | Foreman+Katello uses ~3 GB; 8 GB minimum, 16 GB recommended |
| 100 GB free disk | NixOS partition + Docker volumes + Nix store |
| Internet | Asahi installer + Nix binary cache |
| macOS 13.0+ | Asahi installer requires Ventura or later |
| SSH key with GitHub access | To clone `SocioProphet/prophet-platform` (private) |

---

## Phase A — Asahi Linux install (~20 min)

```sh
curl https://alx.sh | sh
```

Select **"Asahi Linux (minimal)"** when prompted. The installer:
1. Resizes the macOS partition
2. Reboots into an Apple recovery environment to finalize
3. Boots into minimal Fedora Asahi Linux

---

## Phase B — Replace Fedora with NixOS (~15 min)

From the Fedora Asahi shell:

```sh
sudo -i

# Install NixOS over Fedora using nixos-infect.
# NO_REBOOT=1 keeps the session open so we can clone the repo first.
curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-unstable NO_REBOOT=1 bash 2>&1 | tee /tmp/nixos-infect.log

# Verify nixos-infect completed successfully before continuing
grep -q 'configuration changed' /tmp/nixos-infect.log || \
  { echo "nixos-infect may have failed — check /tmp/nixos-infect.log before rebooting"; exit 1; }

# Clone source-os before rebooting into NixOS.
# CRITICAL: do not reboot until this succeeds. If the clone fails, fix the
# issue (SSH key, network) and retry. Rebooting without the repo leaves you
# with a NixOS system you can't enroll without network recovery.
mkdir -p /opt/sourceos
git clone git@github.com:SociOS-Linux/source-os.git /opt/sourceos/source-os || \
  git clone https://github.com/SociOS-Linux/source-os.git /opt/sourceos/source-os || \
  { echo "FATAL: git clone failed. Fix network/SSH access before rebooting."; exit 1; }

echo "Clone successful — safe to reboot."
reboot
```

---

## Phase C — First NixOS boot

Log in as root (no password on first boot). Verify:

```sh
nixos-version   # should show NixOS 25.05 or similar
uname -r        # should include "asahi"
```

---

## Phase D — Enrollment (~35–50 min)

Run the enrollment script as root from the repo root. It is fully automated and idempotent.

```sh
cd /opt/sourceos/source-os
sudo SOURCEOS_REPO_ROOT=$PWD bash scripts/enroll.sh
```

### What it does

| Step | Action | Notes |
|------|--------|-------|
| 0 | Preflight checks | root, NixOS, repo present |
| 1 | `nixos-generate-config` | writes `hosts/builder-aarch64/hardware-configuration.nix` (gitignored) |
| 2 | `nixos-rebuild switch --impure` pass 1 | installs Docker, age, sops, minisign; `--impure` required so gitignored files are visible |
| 3 | Generate age key | `/etc/sourceos/age.key` — device-specific, never leaves the machine |
| 4 | Clone + start Foreman+Katello | `docker compose up` from `prophet-platform`; waits up to 20 min for installer |
| 5 | Katello content setup | org, product, repos, content view via `scripts/katello-sourceos-setup.sh` |
| 6 | Encrypt secrets | Katello password → SOPS-encrypted at `/etc/sourceos/secrets.yaml` |
| 7 | harmonia signing key | `nix-store --generate-binary-cache-key` → `/etc/sourceos/harmonia-signing.{key,pub}` |
| 8 | minisign key + cache signature | key pair → `/etc/sourceos/nix-cache.{pub,sec}`; signs `nix-cache-info` for nginx endpoint |
| 9 | Write `enroll.nix` | device-specific NixOS settings: `signingPublicKey`, `trusted-public-keys`; gitignored, no Nix file patching |
| 10 | Build + push NixOS closure | `nix build` + `nix copy` to local harmonia cache |
| 11 | `nixos-rebuild switch --impure` pass 2 | activates harmonia, nginx, sops-decrypted secrets, signing key |
| 12 | Verify | all systemd services active; first `SyncCycleReceipt` emitted |

### Watching the Foreman installer (step 4)

In a second terminal:

```sh
docker compose -f /opt/prophet-platform/infra/local/docker-compose.foreman-katello.yml \
  logs -f foreman-katello
```

Installation is complete when you see `Installation complete!`. The script waits automatically (up to 20 min).

---

## Phase E — Verify

After the enrollment banner prints:

```sh
bash scripts/doctor.sh
```

Expected: 14 green checks. Key ones:

```
✓  NixOS version                    25.05 (builder-aarch64)
✓  Asahi kernel                     6.x.x-asahi
✓  Docker                           3 katello containers running
✓  Foreman+Katello API              https://127.0.0.1:8443
✓  harmonia (Nix cache)             active
✓  nginx (cache proxy)              active
✓  Nix cache :8101                  http://127.0.0.1:8101
✓  nix-cache-info minisig           signature valid
✓  sourceos-syncd daemon            active since ...
✓  Last sync receipt                outcome=applied, 30s ago
```

---

## Steady-state operation

```
Every 5 min     sourceos-syncd polls Katello stable
                → new version: nix copy → nixos-rebuild → SyncCycleReceipt
                → no change: SyncCycleReceipt (outcome: no_change)

120s post-boot  sourceos-health-check.timer fires
                → healthy: no action
                → unhealthy: sourceos-boot rollback execute → nixos-rebuild --rollback
```

**Trigger a sync immediately:**

```sh
# 1. Promote a new content view version to stable
bash scripts/promote.sh

# 2. Force the daemon to poll now
systemctl restart sourceos-syncd

# 3. Watch it apply
journalctl -u sourceos-syncd -f
```

---

## Architecture notes

### `--impure` requirement

`nixos-rebuild switch` is called with `--impure` because two required files are gitignored:

| File | Why gitignored |
|------|----------------|
| `hosts/builder-aarch64/hardware-configuration.nix` | Contains device-specific UUIDs/paths |
| `hosts/builder-aarch64/enroll.nix` | Contains device-specific keys (signingPublicKey, harmonia trusted-public-key) |

Without `--impure`, Nix copies the flake source to the store and strips gitignored files, making `builtins.pathExists ./enroll.nix` return `false` and the hardware config import fail.

### Secrets model

All secrets live at `/etc/sourceos/` — outside the repo. Nothing device-specific is ever committed.

| File | Content | Protected by |
|------|---------|--------------|
| `/etc/sourceos/age.key` | Device age private key | chmod 600, root only |
| `/etc/sourceos/secrets.yaml` | SOPS-encrypted Katello password | age key |
| `/etc/sourceos/harmonia-signing.key` | Nix cache signing key | chmod 600 |
| `/etc/sourceos/nix-cache.sec` | minisign private key | chmod 600 |
| `/etc/sourceos/katello-admin-password` | Katello admin password (plaintext) | chmod 600, root only |

### harmonia + nginx

harmonia serves `/nix/store` as a Nix binary cache at `127.0.0.1:8099`. nginx wraps it at `:8101` and additionally serves `GET /nix-cache-info.minisig` as a static file. sourceos-syncd fetches both the cache info and the minisig before running `nix copy` to verify the cache identity.

harmonia only starts after `/etc/sourceos/harmonia-signing.key` exists (enforced via `systemd.services.harmonia.unitConfig.ConditionPathExists`).

---

## Troubleshooting

### `error: path 'hardware-configuration.nix' does not exist`
Run step 1 manually: `nixos-generate-config --show-hardware-config > hosts/builder-aarch64/hardware-configuration.nix`, then retry enroll.sh.

### `error: access to absolute path is forbidden in pure eval mode`
You ran `nixos-rebuild` without `--impure`. Always use enroll.sh rather than calling nixos-rebuild directly. For manual rebuilds: `nixos-rebuild switch --flake .#builder-aarch64 --impure`.

### Foreman installer never completes
```sh
docker exec katello-foreman tail -f /var/log/foreman-installer/foreman-installer.log
# Hung on Puppet? Restart: docker compose restart foreman-katello
```

### harmonia not starting
```sh
systemctl status harmonia
# "ConditionPathExists was not met" = key not yet generated
# Run: nix-store --generate-binary-cache-key builder-aarch64-1 \
#        /etc/sourceos/harmonia-signing.key /etc/sourceos/harmonia-signing.pub
# Then: systemctl start harmonia
```

### `sourceos-syncd` fails authentication
Katello password file: `cat /etc/sourceos/katello-admin-password`. Verify it matches Foreman UI at `https://127.0.0.1:8443`.

### Rollback triggered unexpectedly
```sh
sourceos-syncd receipts list       # recent sync history
journalctl -u sourceos-health-check -n 50
sourceos-boot rollback plan        # dry-run the rollback
```

---

## Re-enrollment

The enrollment script is fully idempotent. If a step fails, fix the issue and re-run:

```sh
sudo bash scripts/enroll.sh
```

If the age key or signing keys need to be regenerated (e.g., disk wipe), delete `/etc/sourceos/` and re-run. The SOPS secrets will be re-encrypted with the new age key.

### `secrets.yaml cannot be decrypted with current age key`

The age key changed after secrets were encrypted (e.g., manual deletion + re-run). The old ciphertext is unrecoverable. Delete and re-enroll:

```sh
rm -f /etc/sourceos/secrets.yaml /etc/sourceos/age.key /etc/sourceos/age.pub
sudo bash scripts/enroll.sh
```

### `Partial harmonia/minisign key state detected`

One file of a key pair was deleted. The script refuses to regenerate silently to avoid orphaning cache signatures. Delete the entire pair and re-run:

```sh
rm -f /etc/sourceos/harmonia-signing.key /etc/sourceos/harmonia-signing.pub
rm -f /etc/sourceos/nix-cache.pub /etc/sourceos/nix-cache.sec
sudo bash scripts/enroll.sh
```

### Pass 1 or pass 2 rebuild failed

If `nixos-rebuild switch` fails during enrollment, the previous generation remains bootable. Check the log printed by the script and inspect:

```sh
journalctl -xe | tail -80
# or replay the log file path printed by the script
cat /tmp/sourceos-enroll-pass1-*.log
```

The system can always boot into the previous generation via the systemd-boot menu.
