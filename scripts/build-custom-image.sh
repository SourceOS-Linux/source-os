#!/usr/bin/env bash
# build-custom-image.sh — Build a user-customized SourceOS image from a spec.
#
# Composes a per-build NixOS module on top of a SourceOS edition (the same
# nixosModules.<edition> the installer uses) plus the user's customizations,
# then builds an installer ISO with nixos-generators. Uploads the artifact +
# SHA256 to a per-user GCS prefix.
#
# Driven by the self-serve image builder (socioprophet backend → build-custom.yml).
#
# Spec JSON (stdin or $SPEC_FILE):
#   {
#     "edition":  "desktop" | "server" | "edge",   # base flavor
#     "arch":     "x86_64" | "aarch64",
#     "hostname": "my-host",
#     "packages": ["htop", "tmux", ...],             # nixpkgs attr names
#     "services": { "openssh": true, "docker": false },   # optional (tier-gated upstream)
#     "users":    [{ "name": "alice", "groups": ["wheel"] }]  # optional
#   }
# The backend is responsible for tier/policy gating; this script trusts the
# spec it is given but validates shape + rejects obviously unsafe package names.
#
# Usage:
#   SPEC_FILE=spec.json OUT=out UID=<uid> BUILD_ID=<id> bash scripts/build-custom-image.sh
#   (GCS upload happens only if GCS_PREFIX is set, e.g. gs://bucket/user-builds/<uid>/<id>)
set -euo pipefail

OUT="${OUT:-out}"; mkdir -p "$OUT"
SPEC_FILE="${SPEC_FILE:-/dev/stdin}"
GCS_PREFIX="${GCS_PREFIX:-}"
FLAKE_REF="${FLAKE_REF:-github:SourceOS-Linux/source-os}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
log() { printf '[build-custom] %s\n' "$*"; }
die() { printf '[build-custom] ERROR: %s\n' "$*" >&2; exit 1; }

command -v nix >/dev/null 2>&1 || die "nix required"
command -v jq  >/dev/null 2>&1 || die "jq required"

SPEC="$(cat "$SPEC_FILE")"
echo "$SPEC" | jq empty 2>/dev/null || die "spec is not valid JSON"

EDITION="$(jq -r '.edition // "desktop"' <<<"$SPEC")"
ARCH="$(jq -r '.arch // "x86_64"' <<<"$SPEC")"
HOSTNAME="$(jq -r '.hostname // "sourceos"' <<<"$SPEC")"

case "$EDITION" in desktop) MODULE=desktop-gnome;; server) MODULE=server;; edge) MODULE=edge;; *) die "unknown edition: $EDITION";; esac
case "$ARCH" in x86_64|aarch64) ;; *) die "unknown arch: $ARCH";; esac
[[ "$HOSTNAME" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] || die "invalid hostname: $HOSTNAME"

# Validate package names against a conservative pattern (nixpkgs attr paths).
# This is defense-in-depth; the backend enforces tier policy.
PKGS_NIX=""
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  [[ "$p" =~ ^[a-zA-Z0-9._-]+$ ]] || die "rejected package name: $p"
  PKGS_NIX="$PKGS_NIX pkgs.\"$p\""
done < <(jq -r '.packages // [] | .[]' <<<"$SPEC")

# Optional services (only a safe allow-list is honored here).
SERVICES_NIX=""
for svc in openssh docker; do
  if [[ "$(jq -r --arg s "$svc" '.services[$s] // false' <<<"$SPEC")" == "true" ]]; then
    case "$svc" in
      openssh) SERVICES_NIX="$SERVICES_NIX services.openssh.enable = true;";;
      docker)  SERVICES_NIX="$SERVICES_NIX virtualisation.docker.enable = true;";;
    esac
  fi
done

# Optional users. Each becomes a normal user; groups validated against a safe set.
USERS_NIX=""
while IFS= read -r uname; do
  [[ -z "$uname" ]] && continue
  [[ "$uname" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "invalid username: $uname"
  GROUPS_NIX=""
  while IFS= read -r g; do
    [[ -z "$g" ]] && continue
    case "$g" in wheel|networkmanager|docker|video|audio) GROUPS_NIX="$GROUPS_NIX \"$g\"";; *) die "rejected group: $g";; esac
  done < <(jq -r --arg n "$uname" '.users[]? | select(.name==$n) | .groups[]?' <<<"$SPEC")
  USERS_NIX="$USERS_NIX users.users.\"$uname\" = { isNormalUser = true; extraGroups = [ $GROUPS_NIX ]; };"
done < <(jq -r '.users[]?.name // empty' <<<"$SPEC")

# ── Compose the per-build flake ──────────────────────────────────────────────
mkdir -p "$WORK/build"
cat > "$WORK/build/flake.nix" <<EOF
{
  description = "SourceOS custom build";
  inputs.sourceos.url = "${FLAKE_REF}";
  inputs.nixpkgs.follows = "sourceos/nixpkgs";
  inputs.nixos-generators.follows = "sourceos/nixos-generators";
  outputs = { self, nixpkgs, sourceos, nixos-generators }: {
    packages.${ARCH}-linux.image = nixos-generators.nixosGenerate {
      system = "${ARCH}-linux";
      specialArgs = { self = sourceos; };
      format = "install-iso";
      modules = [
        sourceos.nixosModules.${MODULE}
        ({ pkgs, lib, ... }: {
          networking.hostName = "${HOSTNAME}";
          environment.systemPackages = [ ${PKGS_NIX} ];
          ${SERVICES_NIX}
          ${USERS_NIX}
        })
      ];
    };
  };
}
EOF
log "composed build: edition=$EDITION arch=$ARCH host=$HOSTNAME pkgs=[$(jq -rc '.packages // []' <<<"$SPEC")]"

# ── Build ────────────────────────────────────────────────────────────────────
log "nix build (this is the long step)..."
nix build --no-link --print-out-paths \
  --override-input sourceos "$FLAKE_REF" \
  "$WORK/build#packages.${ARCH}-linux.image" --print-build-logs > "$WORK/outpath" || die "nix build failed"
RESULT="$(cat "$WORK/outpath")"
ISO="$(find -L "$RESULT" -name '*.iso' | head -1)"
[[ -n "$ISO" ]] || die "no ISO produced"

NAME="sourceos-${EDITION}-${ARCH}-custom.iso"
cp "$ISO" "$OUT/$NAME"
( cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256" )
log "built $OUT/$NAME ($(du -h "$OUT/$NAME" | cut -f1))"

# ── Upload ───────────────────────────────────────────────────────────────────
if [[ -n "$GCS_PREFIX" ]]; then
  log "uploading to $GCS_PREFIX/ ..."
  gsutil cp "$OUT/$NAME" "$OUT/$NAME.sha256" "$GCS_PREFIX/"
  echo "$GCS_PREFIX/$NAME" > "$OUT/artifact-url.txt"
  log "artifact: $GCS_PREFIX/$NAME"
fi
log "done."
