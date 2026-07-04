{ writeShellApplication, python3, systemd, coreutils, nftables }:
writeShellApplication {
  name = "meshd-exitd";
  runtimeInputs = [ python3 systemd coreutils nftables ];
  text = ''
    set -euo pipefail

    CONFIG=""
    NFT=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --config)
          CONFIG="$2"
          shift 2
          ;;
        --nft)
          NFT="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    if [ -z "$CONFIG" ] || [ ! -f "$CONFIG" ]; then
      echo "meshd-exitd: missing or unreadable --config path" >&2
      exit 2
    fi

    if [ -z "$NFT" ] || [ ! -f "$NFT" ]; then
      echo "meshd-exitd: missing or unreadable --nft path" >&2
      exit 2
    fi

    exec python3 - "$CONFIG" "$NFT" <<'PY'
import os
import signal
import subprocess
import sys
import time
from typing import Any

config_path = sys.argv[1]
nft_path = sys.argv[2]
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


def validate_nft(path: str) -> None:
    subprocess.run(["nft", "-c", "-f", path], check=True)


signal.signal(signal.SIGTERM, _stop)
signal.signal(signal.SIGINT, _stop)

config = load_toml_like(config_path)
exit_cfg = config.get("exit", {})
routing = config.get("routing", {})

if not exit_cfg.get("allow_full_tunnel", False):
    raise SystemExit("meshd-exitd: full-tunnel exit role is not enabled in the config")

validate_nft(nft_path)

status = f"meshd-exitd active (table={routing.get('exit_route_table')}, fwmark={routing.get('exit_fwmark')})"
if os.environ.get("NOTIFY_SOCKET"):
    subprocess.run(["systemd-notify", "--ready", f"--status={status}"], check=False)

last_nft_mtime = os.path.getmtime(nft_path)
last_cfg_mtime = os.path.getmtime(config_path)

while not stop:
    time.sleep(5)
    cfg_mtime = os.path.getmtime(config_path)
    nft_mtime = os.path.getmtime(nft_path)
    if cfg_mtime != last_cfg_mtime or nft_mtime != last_nft_mtime:
        config = load_toml_like(config_path)
        exit_cfg = config.get("exit", {})
        if not exit_cfg.get("allow_full_tunnel", False):
            raise SystemExit("meshd-exitd: full-tunnel exit role was disabled during reload")
        validate_nft(nft_path)
        last_cfg_mtime = cfg_mtime
        last_nft_mtime = nft_mtime
        if os.environ.get("NOTIFY_SOCKET"):
            subprocess.run(["systemd-notify", f"--status=meshd-exitd revalidated ({nft_path})"], check=False)
PY
  '';
}
