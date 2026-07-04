#!/usr/bin/env bash
# verify-image.sh — Verify a downloaded SourceOS image against its signature
# and provenance. Self-sovereign: needs only the public key (no account, no
# third-party service).
#
# Usage:
#   verify-image.sh <artifact> [pubkey]
#     <artifact>  the downloaded file, e.g. sourceos-desktop-x86_64-custom.iso
#                 (its <artifact>.minisig must sit beside it)
#     [pubkey]    minisign public key line or file; defaults to $SOURCEOS_SIGN_PUBKEY
#
# Exit 0 only if the signature verifies. Also checks the in-toto subject digest
# if <artifact>.intoto.json is present.
set -euo pipefail

ART="${1:?usage: verify-image.sh <artifact> [pubkey]}"
PUB="${2:-${SOURCEOS_SIGN_PUBKEY:-}}"
SIG="$ART.minisig"
[[ -f "$ART" ]] || { echo "no such file: $ART" >&2; exit 2; }
[[ -f "$SIG" ]] || { echo "no signature beside artifact: $SIG" >&2; exit 2; }
[[ -n "$PUB" ]] || { echo "no public key (pass as arg or set SOURCEOS_SIGN_PUBKEY)" >&2; exit 2; }

minisign_run() {
  if command -v minisign >/dev/null 2>&1; then minisign "$@"
  elif command -v nix >/dev/null 2>&1; then nix run nixpkgs#minisign -- "$@"
  else echo "minisign not found (install minisign, or have nix on PATH)" >&2; return 127; fi
}

# minisign accepts either a public-key file (-p) or an inline key (-P).
if [[ -f "$PUB" ]]; then PUB_ARGS=(-p "$PUB"); else PUB_ARGS=(-P "$PUB"); fi

echo "verifying signature of $(basename "$ART") ..."
minisign_run -V "${PUB_ARGS[@]}" -m "$ART"

# Optional: confirm the in-toto attestation's subject digest matches the file.
INTOTO="$ART.intoto.json"
if [[ -f "$INTOTO" ]] && command -v jq >/dev/null 2>&1; then
  want="$(jq -r --arg n "$(basename "$ART")" '.subject[] | select(.name==$n) | .digest.sha256' "$INTOTO")"
  have="$(sha256sum "$ART" | awk '{print $1}')"
  if [[ -n "$want" && "$want" == "$have" ]]; then
    echo "attestation subject digest matches ✅ ($have)"
  elif [[ -n "$want" ]]; then
    echo "ATTESTATION DIGEST MISMATCH ❌ want=$want have=$have" >&2; exit 1
  fi
fi
echo "OK — $(basename "$ART") is authentic."
