{ writeShellApplication, python3, systemd, coreutils }:
writeShellApplication {
  name = "meshd-linkd";
  runtimeInputs = [ python3 systemd coreutils ];
  text = ''
    set -euo pipefail

    RPC=""
    CONTROL=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --rpc)
          RPC="$2"
          shift 2
          ;;
        --control)
          CONTROL="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    case "$RPC" in
      unix:*) RPC_PATH="''${RPC#unix:}" ;;
      *) echo "meshd-linkd: --rpc must be a unix: URI" >&2; exit 2 ;;
    esac

    case "$CONTROL" in
      unix:*) CONTROL_PATH="''${CONTROL#unix:}" ;;
      *) echo "meshd-linkd: --control must be a unix: URI" >&2; exit 2 ;;
    esac

    mkdir -p "$(dirname "$RPC_PATH")"

    exec python3 - "$RPC_PATH" "$CONTROL_PATH" <<'PY'
import json
import os
import select
import signal
import socket
import subprocess
import sys
import time
from typing import Any

rpc_path = sys.argv[1]
control_path = sys.argv[2]
stop = False


def _stop(*_args):
    global stop
    stop = True


def recv_json(conn: socket.socket) -> dict[str, Any]:
    data = b""
    while True:
        chunk = conn.recv(65536)
        if not chunk:
            break
        data += chunk
        if b"\n" in chunk:
            break
    if not data:
        return {"ok": False, "error": "empty response"}
    return json.loads(data.decode("utf-8").strip())


def send_json(conn: socket.socket, payload: dict[str, Any]) -> None:
    conn.sendall((json.dumps(payload, sort_keys=True) + "\n").encode("utf-8"))


def call_control(payload: dict[str, Any]) -> dict[str, Any]:
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(5)
    conn.connect(control_path)
    with conn:
        send_json(conn, payload)
        return recv_json(conn)


def read_request(conn: socket.socket) -> dict[str, Any]:
    data = b""
    while True:
        chunk = conn.recv(65536)
        if not chunk:
            break
        data += chunk
        if b"\n" in chunk:
            break
    if not data:
        return {"op": "ping"}
    text = data.decode("utf-8").strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"op": "ping", "raw": text}


def register() -> dict[str, Any]:
    return call_control({
        "op": "register-helper",
        "helper": "linkd",
        "socket": rpc_path,
        "capabilities": ["get-link-plan", "get-manifest", "status"],
    })


signal.signal(signal.SIGTERM, _stop)
signal.signal(signal.SIGINT, _stop)

for _ in range(30):
    if os.path.exists(control_path):
        try:
            ping = call_control({"op": "ping"})
            if ping.get("ok"):
                break
        except Exception:
            pass
    time.sleep(1)
else:
    raise SystemExit("meshd-linkd: control socket never became ready")

registration = register()

try:
    os.unlink(rpc_path)
except FileNotFoundError:
    pass

srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(rpc_path)
srv.listen(16)

if os.environ.get("NOTIFY_SOCKET"):
    subprocess.run([
        "systemd-notify",
        "--ready",
        f"--status=meshd-linkd active ({rpc_path})"
    ], check=False)

while not stop:
    ready, _, _ = select.select([srv], [], [], 1.0)
    if srv not in ready:
        continue
    conn, _ = srv.accept()
    with conn:
        req = read_request(conn)
        op = req.get("op", "ping")
        if op == "ping":
            send_json(conn, {"ok": True, "service": "meshd-linkd", "socket": rpc_path})
            continue
        if op == "status":
            status = call_control({"op": "status"})
            send_json(conn, {
                "ok": True,
                "service": "meshd-linkd",
                "registration": registration,
                "upstream": status,
            })
            continue
        if op == "get-link-plan":
            send_json(conn, call_control({"op": "render-link-plan"}))
            continue
        if op == "get-manifest":
            send_json(conn, call_control({"op": "get-manifest"}))
            continue
        if op == "refresh-registration":
            registration = register()
            send_json(conn, {"ok": True, "service": "meshd-linkd", "registration": registration})
            continue
        send_json(conn, {"ok": False, "service": "meshd-linkd", "error": f"unsupported op: {op}"})

srv.close()
try:
    os.unlink(rpc_path)
except FileNotFoundError:
    pass
PY
  '';
}
