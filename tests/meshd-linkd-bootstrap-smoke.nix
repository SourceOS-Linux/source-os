{ pkgs ? import <nixpkgs> {}, self, system }:
pkgs.runCommand "meshd-linkd-bootstrap-smoke" {
  nativeBuildInputs = [ pkgs.python3 self.packages.${system}.meshd self.packages.${system}.meshd-linkd ];
} ''
  workdir="$TMPDIR/meshd-linkd-bootstrap"
  mkdir -p "$workdir" "$out"

  manifest="$workdir/manifest.json"
  config="$workdir/meshd.toml"
  control_socket="$workdir/meshd.sock"
  rpc_socket="$workdir/linkd.sock"

  cat > "$manifest" <<'JSON'
{"version":"capability-manifest/v0","node_id":"node-linkd","roles":["relay"],"transports":["wireguard"],"path_templates":["P0-direct","P1-relay"]}
JSON

  cat > "$config" <<EOF
[identity]
role = "relay"
manager = "networkd"
interface = "mesh0"

[paths]
manifest = "$manifest"
control_socket = "unix:$control_socket"
link_socket = "unix:$rpc_socket"

[routing]
private_fwmark = "0x110"
exit_fwmark = "0x120"
private_route_table = 110
exit_route_table = 120
onion_route_table = 130
mix_route_table = 140
EOF

  meshd --config "$config" --listen "unix:$control_socket" &
  meshd_pid=$!
  meshd-linkd --rpc "unix:$rpc_socket" --control "unix:$control_socket" &
  linkd_pid=$!
  trap 'kill "$linkd_pid" "$meshd_pid" 2>/dev/null || true' EXIT

  python3 - "$rpc_socket" <<'PY'
import json
import os
import socket
import sys
import time

sock = sys.argv[1]
for _ in range(100):
    if os.path.exists(sock):
        break
    time.sleep(0.1)
else:
    raise SystemExit("meshd-linkd socket never appeared")

def call(op: str):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.connect(sock)
    conn.sendall((json.dumps({"op": op}) + "\n").encode("utf-8"))
    data = b""
    while True:
        chunk = conn.recv(65536)
        if not chunk:
            break
        data += chunk
        if b"\n" in chunk:
            break
    conn.close()
    return json.loads(data.decode("utf-8").strip())

ping = call("ping")
assert ping["ok"] is True and ping["service"] == "meshd-linkd"
status = call("status")
assert status["registration"]["registered"] == "linkd"
assert status["upstream"]["identity"]["role"] == "relay"
plan = call("get-link-plan")
assert plan["plan"]["role"] == "relay"
manifest = call("get-manifest")
assert manifest["payload"]["node_id"] == "node-linkd"
refresh = call("refresh-registration")
assert refresh["registration"]["registered"] == "linkd"
PY

  kill "$linkd_pid" "$meshd_pid"
  wait "$linkd_pid" || true
  wait "$meshd_pid" || true
  echo validated > "$out/result.txt"
''
