#!/usr/bin/env bash
# harness.sh — orchestrate an Agent-S GUI test of a SourceOS image.
#
# Linux (GCP/CI): starts an Xvfb virtual display, boots the VM full-screen on it
# via a VNC→X bridge, then runs the Agent-S driver against that display.
# macOS: run this inside a Linux VM (lima/colima/docker) — pyautogui driving the
# host screen directly is unsafe.
#
# Usage:
#   IMG=/path/to/desktop.qcow2 AS_GROUND_URL=http://localhost:8080/v1 \
#   ANTHROPIC_API_KEY=... bash tests/agent-s/harness.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${IMG:?set IMG=/path/to/bootable.qcow2}"
ARTIFACTS="${AS_ARTIFACTS:-$HERE/artifacts}"; mkdir -p "$ARTIFACTS"
RES="${RES:-1920x1080x24}"

if [ "$(uname -s)" != "Linux" ]; then
  echo "This harness expects Linux (Xvfb). On macOS, run it inside a Linux VM." >&2
  exit 1
fi
for b in Xvfb x11vnc qemu-system-x86_64 python3; do
  command -v "$b" >/dev/null 2>&1 || { echo "missing dependency: $b" >&2; exit 1; }
done

cleanup() { for p in "${VM_PID:-}" "${VNCV_PID:-}" "${XVFB_PID:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

# 1. Virtual display.
export DISPLAY=":99"
Xvfb "$DISPLAY" -screen 0 "$RES" >"$ARTIFACTS/xvfb.log" 2>&1 & XVFB_PID=$!
sleep 2

# 2. Boot the VM (headless QEMU exposing VNC :0 → 5900), then mirror VNC onto X.
VNC=":0" HEADLESS=1 IMG="$IMG" bash "$HERE/run-vm.sh" >"$ARTIFACTS/qemu.log" 2>&1 & VM_PID=$!
sleep 5
# Bridge the guest's VNC onto our Xvfb screen so pyautogui sees/controls it.
( command -v vncviewer >/dev/null 2>&1 && vncviewer -FullScreen localhost:5900 ) \
  >"$ARTIFACTS/vncviewer.log" 2>&1 & VNCV_PID=$!

echo "[harness] waiting for guest to boot to desktop (~60-120s)..."
sleep "${BOOT_WAIT:-90}"

# 3. Drive it with Agent-S.
AS_ARTIFACTS="$ARTIFACTS" python3 "$HERE/agent_test.py"
RC=$?
echo "[harness] result rc=$RC — artifacts in $ARTIFACTS"
exit "$RC"
