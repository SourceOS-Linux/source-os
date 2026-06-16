# source-os

NixOS realization root for the SourceOS Linux control-plane stack.

## Enroll an M2

```sh
# Phase A — install Asahi Linux (see docs/bootstrap/M2_ENROLL.md)
curl https://alx.sh | sh

# Phase B — replace Fedora with NixOS
curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-unstable NO_REBOOT=1 bash
git clone https://github.com/SociOS-Linux/source-os.git /opt/sourceos/source-os
reboot

# Phase C — enroll (run as root from the repo root, ~35 min)
sudo bash scripts/enroll.sh

# Verify
bash scripts/doctor.sh
```

Full runbook: [`docs/bootstrap/M2_ENROLL.md`](docs/bootstrap/M2_ENROLL.md)

## What enrollment gives you

| Component | What it does |
|-----------|-------------|
| `sourceos-syncd` daemon | Polls local Katello every 5 min; applies NixOS updates; emits `SyncCycleReceipt` |
| `sourceos-boot` rollback | Auto-rolls back if post-boot health check fails |
| `harmonia` | Local Nix binary cache served at `http://127.0.0.1:8101` |
| Foreman+Katello | Local content lifecycle manager (Docker, linux/amd64 via qemu) |
| SOPS secrets | Katello password encrypted with device age key; never committed |

## Day-2 operations

```sh
# Check full stack health
bash scripts/doctor.sh

# Promote a new build to stable (triggers daemon sync within 5 min)
bash scripts/promote.sh --version <CV_VERSION>

# Daemon status
sourceos-syncd sync status

# Last sync receipt
sourceos-syncd receipts last

# Live daemon logs
journalctl -u sourceos-syncd -f
```

## Repository layout

- `hosts/builder-aarch64/` — M2 Asahi NixOS host config
- `modules/nixos/sourceos-syncd/` — NixOS module for the sync daemon
- `packages/sourceos-syncd/` / `packages/sourceos-boot/` — Nix derivations
- `scripts/enroll.sh` — one-shot M2 enrollment
- `scripts/doctor.sh` — full stack health check
- `scripts/promote.sh` — promote Katello content view to stable
- `scripts/katello-sourceos-setup.sh` — idempotent Katello org/product setup
- `docs/bootstrap/M2_ENROLL.md` — detailed enrollment runbook
- `profiles/` / `modules/` — shared NixOS profiles and modules

## Boundary rule

Shared schemas and canonical vocabulary belong in `SocioProphet/socioprophet-agent-standards`, not here.
