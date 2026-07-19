{ pkgs ? import <nixpkgs> {}, self, system }:
pkgs.runCommand "meshd-exitd-bootstrap-smoke" {
  nativeBuildInputs = [ pkgs.python3 self.packages.${system}.meshd-exitd ];
} ''
  workdir="$TMPDIR/meshd-exitd-bootstrap"
  mkdir -p "$workdir" "$out"

  config="$workdir/exits.toml"
  nft="$workdir/mesh-exit.nft"

  cat > "$config" <<EOF
[exit]
interface = "mesh0"
nft_policy = "$nft"
allow_full_tunnel = true

[routing]
exit_fwmark = "0x120"
exit_route_table = 120
EOF

  cat > "$nft" <<'NFT'
table inet mesh_exit {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
  }
}
NFT

  meshd-exitd --config "$config" --nft "$nft" &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true' EXIT

  sleep 2
  kill -0 "$pid"

  echo '# reload probe' >> "$nft"
  touch "$config"
  sleep 6
  kill -0 "$pid"

  kill "$pid"
  wait "$pid" || true
  echo validated > "$out/result.txt"
''
