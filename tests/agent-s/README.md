# SourceOS image testing — two layers

Validate that SourceOS images actually boot and work, before cutting a release.

## Layer 1 — deterministic boot tests (no LLM, free, runs anywhere)

NixOS VM tests that boot each edition in QEMU and assert on it. No GUI agent, no
API keys, fully reproducible.

```sh
nix build .#checks.x86_64-linux.edition-desktop-boot   # GNOME → display-manager + graphical.target
nix build .#checks.x86_64-linux.edition-server-boot    # headless → sshd + firewall, no DM
nix build .#checks.x86_64-linux.edition-edge-boot       # appliance → sshd + zram, no DM
```

Runs on any Linux with KVM — GitHub CI (`image-tests.yml`), a GCP VM, or a local
Linux box. This is the primary gate; **Layer 2 is additive.**

## Layer 2 — Agent-S GUI test (human-like, needs a grounding model + key)

Boots a *pre-installed desktop image* and drives it with [Agent-S](https://github.com/SocioProphet/Agent-S)
to confirm the GNOME desktop is usable like a human would — open Activities,
launch Files, see a window appear.

### What you need

- A bootable desktop disk image:
  `nix build .#packages.x86_64-linux.sourceos-image-qcow2-desktop` → `result/*.qcow2`
- A **grounding model** endpoint (Agent-S S3 separates generation from grounding).
  UI-TARS-1.5-7B on vLLM/TGI is the recommended grounder — it needs a GPU, so
  Layer 2 belongs on a **GCP GPU VM** (or any host with the endpoint reachable).
- A main-model key: `ANTHROPIC_API_KEY` (default provider `anthropic`,
  `claude-sonnet-4-6`) or `OPENAI_API_KEY` with `AS_PROVIDER=openai`.

### Run (Linux / GCP GPU VM)

```sh
pip install -r tests/agent-s/requirements.txt
export ANTHROPIC_API_KEY=...                 # main model
export AS_GROUND_URL=http://localhost:8080/v1 # UI-TARS endpoint
IMG="$(readlink -f result)"/*.qcow2 \
  bash tests/agent-s/harness.sh
# → tests/agent-s/artifacts/{step-NN.png, result.json}; exit 0 = desktop verified
```

### Per surface

| Surface | How |
|---|---|
| **GCP VM (nested KVM + GPU)** | Run `harness.sh` directly; KVM accelerates QEMU, the GPU serves UI-TARS. Most robust for x86_64. |
| **GitHub CI** | Layer 1 only (free, KVM). Layer 2 is gated in `image-tests.yml` behind `run_agent_s` + an `ANTHROPIC_API_KEY` secret and an external `AS_GROUND_URL`. |
| **Local Mac** | Native aarch64 guests boot fast (HVF). Run the harness **inside a Linux VM** (lima/colima) — pyautogui must not drive the host screen. |

### Files

- `run-vm.sh` — portable QEMU launcher (KVM/HVF/TCG auto-selected), VNC display.
- `harness.sh` — Xvfb + VM boot + Agent-S driver + artifact capture (Linux).
- `agent_test.py` — the Agent-S S3 driver (screenshot → predict → act loop).

> Status: the harness is wired against the Agent-S SDK and the portable QEMU
> path; it needs a live grounding endpoint + key to run end-to-end and has not
> yet been executed against a real image. Layer 1 is the validated gate today.
