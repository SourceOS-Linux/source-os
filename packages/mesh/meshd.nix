{ writeShellApplication, python3, systemd, coreutils }:
writeShellApplication {
  name = "meshd";
  runtimeInputs = [ python3 systemd coreutils ];
  text = ''
    set -euo pipefail

    CONFIG=""
    LISTEN=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --config)
          CONFIG="$2"
          shift 2
          ;;
        --listen)
          LISTEN="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    if [ -z "$CONFIG" ] || [ ! -f "$CONFIG" ]; then
      echo "meshd: missing or unreadable --config path" >&2
      exit 2
    fi

    case "$LISTEN" in
      unix:*)
        SOCKET_PATH="''${LISTEN#unix:}"
        ;;
      *)
        echo "meshd: only unix: listeners are supported by this bootstrap package" >&2
        exit 2
        ;;
    esac

    mkdir -p "$(dirname "$SOCKET_PATH")"

    exec python3 - "$CONFIG" "$SOCKET_PATH" <<'PY'
import json
import os
import select
import signal
import socket
import subprocess
import sys
import time
from typing import Any

config_path = sys.argv[1]
socket_path = sys.argv[2]
stop = False


def _stop(*_args):
    global stop
    stop = True


def parse_value(raw: str) -> Any:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw.lower() in {"true", "false"}:
        return raw.lower() == "true"
    try:
        return int(raw)
    except ValueError:
        return raw


def load_toml_like(path: str) -> dict[str, dict[str, Any]]:
    data: dict[str, dict[str, Any]] = {}
    section = "root"
    data[section] = {}
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1].strip()
                data.setdefault(section, {})
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            data.setdefault(section, {})[key.strip()] = parse_value(value)
    return data


def manifest_payload(path: str | None) -> dict[str, Any]:
    if not path:
        return {"exists": False, "path": None, "payload": None}
    if not os.path.exists(path):
        return {"exists": False, "path": path, "payload": None}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return {"exists": True, "path": path, "payload": json.load(handle)}
    except Exception as exc:
        return {"exists": True, "path": path, "payload": None, "error": str(exc)}


def response(conn: socket.socket, payload: dict[str, Any]) -> None:
    conn.sendall((json.dumps(payload, sort_keys=True) + "\n").encode("utf-8"))


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
    if not text:
        return {"op": "ping"}
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"op": "ping", "raw": text}


signal.signal(signal.SIGTERM, _stop)
signal.signal(signal.SIGINT, _stop)

config = load_toml_like(config_path)
identity = config.get("identity", {})
paths = config.get("paths", {})
routing = config.get("routing", {})
state: dict[str, Any] = {
    "helpers": {},
    "started_at": int(time.time()),
}

try:
    os.unlink(socket_path)
except FileNotFoundError:
    pass

srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(socket_path)
srv.listen(16)

if os.environ.get("NOTIFY_SOCKET"):
    subprocess.run([
        "systemd-notify",
        "--ready",
        f"--status=meshd control plane active ({socket_path})"
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
            response(conn, {"ok": True, "service": "meshd", "socket": socket_path})
            continue

        if op == "status":
            response(conn, {
                "ok": True,
                "service": "meshd",
                "identity": identity,
                "paths": paths,
                "routing": routing,
                "helpers": state["helpers"],
                "started_at": state["started_at"],
            })
            continue

        if op == "get-manifest":
            response(conn, {"ok": True, "service": "meshd", **manifest_payload(paths.get("manifest"))})
            continue

        if op == "render-link-plan":
            response(conn, {
                "ok": True,
                "service": "meshd",
                "plan": {
                    "interface": identity.get("interface"),
                    "role": identity.get("role"),
                    "manager": identity.get("manager"),
                    "routing": routing,
                    "manifest": paths.get("manifest"),
                    "control_socket": paths.get("control_socket"),
                    "link_socket": paths.get("link_socket"),
                },
            })
            continue

        if op == "register-helper":
            helper = req.get("helper", "unknown")
            state["helpers"][helper] = {
                "socket": req.get("socket"),
                "capabilities": req.get("capabilities", []),
                "registered_at": int(time.time()),
            }
            response(conn, {"ok": True, "service": "meshd", "registered": helper})
            continue

        response(conn, {"ok": False, "service": "meshd", "error": f"unsupported op: {op}"})

srv.close()
try:
    os.unlink(socket_path)
except FileNotFoundError:
    pass
PY
  '';
}
