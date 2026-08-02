# SourceOS on Guix — migration spike

Status: **spike** (additive; does not touch the Nix build). Decision recorded:
migrate the SourceOS substrate from Nix → Guix, driven by Nix-project governance
instability. `nonguix` gives us the same nonfree posture we already run under
nixpkgs `allowUnfree` — the freedom stance is unchanged; we are **not** chasing
the FSF/FSDG zero-blob badge.

## What's here
- `channels.scm` — upstream Guix + `nonguix` (the `allowUnfree` analog), with
  nonguix's published signing introduction. **Pin the commits** via
  `guix pull && guix describe` on the first runner (offline hashes can't be real).
- `system/workstation.scm` — the first parity target: a plain x86_64 workstation
  using the real Linux kernel + firmware + CPU microcode from nonguix.

## Build (on a Linux runner — NOT macOS)
Requires the `guix-daemon` on Linux; it cannot run from a macOS session.

```bash
guix time-machine -C guix/channels.scm -- system build guix/system/workstation.scm
guix time-machine -C guix/channels.scm -- system vm    guix/system/workstation.scm  # boot-test
```

## Why the spike is scoped this way
The philosophy is settled; the only real risk is **nonguix hardware-enablement
maturity** for our two hardest targets. The spike proves them in order:

1. **x86_64 workstation** (`system/workstation.scm`) — baseline parity.
2. **Apple Silicon / Asahi on Guix** — exists but far less trodden than Asahi-on-Nix.
3. **CUDA / GPU model-serving node** — packaged via nonguix; smaller/less
   battle-tested than nixpkgs.

If 2 and 3 build and boot with working hardware, the migration path is real. If
one hits a wall, we've learned it cheaply — before touching the estate.

## Phased plan (prove-then-cut, same discipline as the board parity)
1. **Spike** — this directory: prove the three targets build/boot.
2. **Parity** — re-express `modules/nixos/*` as Guix services/system config, the
   base-OS profiles first (SourceOS territory).
3. **Cutover** — a Guix image-build workflow alongside `nix-build-images`; run
   both; flip the default once parity holds. Nix stays until then.

## Honest limits
- These files are authored and reviewed but **not build-validated** here (no guix
  on macOS). First `guix system build` on a Linux runner is the real gate.
- Reproducibility is not achieved until `channels.scm` commits are pinned.
- Lix (drop-in Nix fork) remains the cheaper stability-only hedge if the Guix
  spike's hardware targets prove too immature; keep it in reserve.
