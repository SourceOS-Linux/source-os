#!/usr/bin/env bash
# Build the SourceOS *Guix* desktop image and run the Agent-S GUI test against
# it, LOCAL or CLOUD, with a LOCAL main model by default.
#
# This wires the Guix build (guix/system/desktop.scm) to the existing Agent-S
# harness (tests/agent-s/harness.sh) — the harness is image-source-agnostic
# (it just needs IMG=*.qcow2 + a grounder + a main model), so a Guix-built
# image drops straight in alongside the Nix one.
#
#   Modes:
#     --mode local   build + boot on this Linux/KVM host (default)
#     --mode cloud   build + run on a GCP GPU VM (grounder on the GPU)
#   Main model (Agent-S generation model) — LOCAL by default, per the estate's
#   local-agent-default posture:
#     --main-model local      use AS_MAIN_URL (a local vLLM/TGI endpoint) [default]
#     --main-model anthropic  use ANTHROPIC_API_KEY
#     --main-model openai     use OPENAI_API_KEY
#
# Requires (Linux runner): guix, qemu (+ /dev/kvm for local), and a reachable
# grounding-model endpoint (UI-TARS on a GPU). NOT runnable from macOS.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

MODE="local"
MAIN_MODEL="local"
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --main-model) MAIN_MODEL="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Local-first main model: default to a local endpoint; only reach for an external
# provider when explicitly requested (and only then require its key).
case "$MAIN_MODEL" in
  local)
    : "${AS_MAIN_URL:?set AS_MAIN_URL to a local main-model endpoint (e.g. http://localhost:8081/v1)}"
    export AS_PROVIDER="local" AS_MAIN_URL
    ;;
  anthropic) : "${ANTHROPIC_API_KEY:?set ANTHROPIC_API_KEY}"; export AS_PROVIDER="anthropic" ;;
  openai)    : "${OPENAI_API_KEY:?set OPENAI_API_KEY}";       export AS_PROVIDER="openai" ;;
  *) echo "unknown --main-model: $MAIN_MODEL" >&2; exit 2 ;;
esac

# Grounder (UI-TARS): local endpoint by default; overridable for cloud/GPU host.
export AS_GROUND_URL="${AS_GROUND_URL:-http://localhost:8080/v1}"

build_guix_image() {
  command -v guix >/dev/null 2>&1 || { echo "missing guix (Linux runner only)" >&2; exit 1; }
  echo "building Guix desktop image (pinned channels)…" >&2
  local out
  out="$(guix time-machine -C "$REPO/guix/channels.scm" -- \
           system image -t qcow2 "$REPO/guix/system/desktop.scm")"
  echo "$out"
}

case "$MODE" in
  local)
    [ -e /dev/kvm ] || echo "warn: no /dev/kvm — boot will be slow (TCG)" >&2
    IMG="$(build_guix_image)"
    echo "running Agent-S locally against $IMG (provider=$AS_PROVIDER)" >&2
    IMG="$IMG" bash "$HERE/harness.sh"
    ;;
  cloud)
    # Run the whole flow ON a GCP GPU VM so the UI-TARS grounder is local to the
    # GPU: sync the repo up, then invoke --mode local there. The VM itself
    # (provisioned with a GPU + guix + qemu/kvm) is supplied via GCP_HOST; how it
    # is spun up (gcloud/Terraform) is out of scope for this runner.
    : "${GCP_HOST:?set GCP_HOST=user@vm — a reachable GCP GPU VM with guix + kvm}"
    echo "cloud mode: sync repo to $GCP_HOST and run --mode local there (grounder on the GPU)." >&2
    rsync -a --delete --exclude '.git' "$REPO/" "$GCP_HOST:sourceos/"
    # AS_GROUND_URL defaults to the VM's local grounder; forward the model choice.
    exec ssh "$GCP_HOST" \
      "cd sourceos && AS_GROUND_URL='${AS_GROUND_URL}' bash tests/agent-s/run-guix.sh --mode local --main-model '${MAIN_MODEL}'"
    ;;
  *) echo "unknown --mode: $MODE" >&2; exit 2 ;;
esac
