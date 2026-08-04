# Nix baseline — the Guix migration parity target

This document copiously inventories the **current Nix setup** so the Guix
implementation can reproduce **the same standards**. It is the parity checklist:
the migration is not "done" for a row until its Guix equivalent builds/boots/passes
to the same bar. Keep it updated as `flake.nix` evolves — it is the source of
truth for what Guix must match, the same way `board-spec.yaml` is for the boards.

Status legend: ☐ not started · ◐ spiked · ☑ parity proven on a Linux runner.

## 1. Packages (`flake.nix` `packages`)
| Nix output | Source | Guix equivalent | Status |
|---|---|---|---|
| `meshd`, `meshd-linkd`, `meshd-exitd` | `packages/mesh/*.nix` | Guix package definitions (`guix/packages/mesh.scm`) | ☐ |
| `bearbrowser` | `packages/browser/bearbrowser.nix` | Guix package (LibreWolf-derived; nonguix for nonfree bits) | ☐ |
| `lampstand` | `packages/search/lampstand.nix` | Guix package | ☐ |
| `sourceos-syncd` | `packages/sourceos-syncd/default.nix` | Guix package | ☐ |
| `sourceos-boot` | `packages/sourceos-boot/default.nix` | Guix package | ☐ |
| `hellgraph` | `packages/hellgraph/default.nix` | `guix/packages/hellgraph.scm` — copy-build-system, wraps Node.js entrypoints | ◐ |

## 2. Images (`flake.nix`, via `nixos-generators`)
| Nix image | Def | Guix equivalent (`guix system image -t …`) | Status |
|---|---|---|---|
| `sourceos-installer-iso` (x86_64 / aarch64) | `images/iso-x86_64.nix`, `images/iso-aarch64.nix` | `guix system image -t iso9660` from a Guix installer profile | ☐ |
| `sourceos-image-qcow2-desktop` | desktop generator | `guix/system/desktop.scm` → `-t qcow2` | ◐ (this PR) |
| `sourceos-image-qcow2-canary` | `images/canary-x86_64.nix` | Guix canary profile → qcow2 | ☐ |
| `sourceos-image-qcow2-stable` | `images/release-x86_64.nix` | Guix stable/release profile → qcow2 | ☐ |
| (workstation baseline) | — | `guix/system/workstation.scm` | ◐ (spike) |

## 3. NixOS modules → Guix services
| Nix module | Path | Guix equivalent (service type) | Status |
|---|---|---|---|
| mesh | `modules/nixos/mesh` | `guix/services/mesh.scm` | ☐ |
| sourceos-shell | `modules/nixos/sourceos-shell` | `guix/services/sourceos-shell.scm` | ☐ |
| sourceos-syncd | `modules/nixos/sourceos-syncd` | `guix/services/sourceos-syncd.scm` | ☐ |
| hellgraph | `modules/nixos/hellgraph` | `guix/services/hellgraph.scm` — shepherd service, superpeer opt-in, credential file | ◐ |

## 4. Checks / tests (`tests/`, `flake.nix` `checks`)
The primary gate is Layer-1 deterministic boot; the contract/smoke suite asserts
each edition + component. Guix's analog is **`guix system test`** (marionette).
| Nix check | Guix equivalent | Status |
|---|---|---|
| edition boot: `tests/{desktop,server,edge}-boot.nix` | `guix system test` per profile (graphical.target / sshd+firewall / zram) | ☐ |
| `*-smoke.nix` / `*-contract.nix` (mesh, sourceos-shell, sourceos-syncd, boot, canary, stable, exit, builder, workstation) | Guix system tests + package tests, one per contract | ☐ |
| Agent-S Layer-2 GUI test (`tests/agent-s/`) | **Already wired**: `tests/agent-s/run-guix.sh` builds `guix/system/desktop.scm` and drives it (local/cloud) | ◐ (this PR) |

## 5. CI workflows
| Nix workflow | Purpose | Guix equivalent | Status |
|---|---|---|---|
| `nix-ci.yml` | flake check / fmt | `guix` lint + `guix system build` of each profile | ☐ |
| `nix-build-images.yml` | build images | build qcow2/iso via `guix system image` | ☐ |
| `image-tests.yml` | Layer-1 boot + Agent-S | `guix system test` + `run-guix.sh` | ☐ |
| `build-custom.yml`, `release-images.yml` | custom/release builds | Guix release build + publish | ☐ |

## 6. Substitutes (cache) + signing
| Nix | Doc | Guix equivalent | Status |
|---|---|---|---|
| Binary cache | `docs/NIX_CACHE_SETUP.md` | `guix publish` server + client `--substitute-urls`; authorize the key with `guix archive --authorize` | ☐ |
| Image signing | `docs/SIGNING_SETUP.md` | Guix signs substitutes with its own key; map the estate signing/WIF flow onto `guix publish` keys | ☐ |

## 7. Dev shells
| Nix | Guix equivalent | Status |
|---|---|---|
| `devShells.default` (`git jq nixpkgs-fmt`) | `guix shell git jq` (+ a `guix/manifests/dev.scm`) | ☐ |
| lampstand dev shell | `guix shell -m guix/manifests/lampstand.scm` | ☐ |

## Parity acceptance
A row flips to ☑ only when its Guix artifact **builds and (for images) boots**
on a Linux runner and passes the same assertion its Nix counterpart does — proved,
not asserted. Cutover (flip the default from Nix to Guix) happens per-profile
once its whole column is ☑, with Nix kept until then.
