{ pkgs ? import <nixpkgs> {}, self, system }:
pkgs.runCommand "meshd-bootstrap-smoke" {
  nativeBuildInputs = [ pkgs.python3 self.packages.${system}.meshd ];
} ''
  workdir="$TMPDIR/meshd-bootstrap"
  mkdir -p "$workdir" "$out"

  manifest="$workdir/manifest.json"
  config="$workdir/meshd.toml"
  socket="$workdir/meshd.sock"
  link_socket="$workdir/linkd.sock"

  cat > "$manifest" <<'JSON'
{"version":"capability-manifest/v0","node_id":"node-test","roles":["peer"],"transports":["wireguard"],"path_templates":["P0-direct"]}
JSON

  cat > "$config" <<EOF
[identity]
role = "peer"
manager = "networkd"
interface = "mesh0"

[paths]
manifest = "$manifest"
control_socket = "unix:$socket"
link_socket = "unix:$link_socket"

[routing]
private_fwmark = "0x110"
exit_fwmark = "0x120"
private_route_table = 110
exit_route_table = 120
onion_route_table = 130
mix_route_table = 140
EOF

  meshd --config "$config" --listen "unix:$socket" &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true' EXIT

  python3 - "$socket" <<'PY'
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
    raise SystemExit("meshd socket never appeared")

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
assert ping["ok"] is True and ping["service"] == "meshd"
status = call("status")
assert status["identity"]["role"] == "peer"
assert status["routing"]["exit_route_table"] == 120
manifest = call("get-manifest")
assert manifest["exists"] is True
assert manifest["payload"]["node_id"] == "node-test"
plan = call("render-link-plan")
assert plan["plan"]["interface"] == "mesh0"
assert plan["plan"]["role"] == "peer"
PY

  kill "$pid"
  wait "$pid" || true
  echo validated > "$out/result.txt"
''
