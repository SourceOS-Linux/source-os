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
TARGET="${TARGET:-iso}"   # iso (download) | netboot (nlboot fleet)
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

# Optional raw module snippet (premium "module editor"). The backend only
# forwards this for premium tier; we additionally refuse import-from-derivation
# and obvious escapes. It is evaluated inside the Nix sandbox (no network at
# build, no host access) — the snippet is NixOS module config, not arbitrary code.
SNIPPET="$(jq -r '.moduleSnippet // ""' <<<"$SPEC")"
if [[ -n "$SNIPPET" ]]; then
  echo "$SNIPPET" | grep -qE 'builtins\.(exec|getEnv|fetch|readFile|path)|import +<|/nix/store|\.\./' \
    && die "module snippet contains a disallowed construct"
fi

# ── Compose the per-build flake (both targets share the customization module) ──
mkdir -p "$WORK/build"
cat > "$WORK/build/flake.nix" <<EOF
{
  description = "SourceOS custom build";
  inputs.sourceos.url = "${FLAKE_REF}";
  inputs.nixpkgs.follows = "sourceos/nixpkgs";
  inputs.nixos-generators.follows = "sourceos/nixos-generators";
  outputs = { self, nixpkgs, sourceos, nixos-generators }:
  let
    custom = ({ pkgs, lib, modulesPath, ... }: {
      networking.hostName = "${HOSTNAME}";
      environment.systemPackages = [ ${PKGS_NIX} ];
      ${SERVICES_NIX}
      ${USERS_NIX}
      ${SNIPPET}
    });
  in {
    # Downloadable installer ISO.
    packages.${ARCH}-linux.image = nixos-generators.nixosGenerate {
      system = "${ARCH}-linux";
      specialArgs = { self = sourceos; };
      format = "install-iso";
      modules = [ sourceos.nixosModules.${MODULE} custom ];
    };
    # Netboot system (kernel + RAM-disk squashfs) for the nlboot fleet.
    nixosConfigurations.netboot = nixpkgs.lib.nixosSystem {
      system = "${ARCH}-linux";
      specialArgs = { self = sourceos; };
      modules = [
        ({ modulesPath, ... }: { imports = [ "\${modulesPath}/installer/netboot/netboot-minimal.nix" ]; })
        sourceos.nixosModules.${MODULE}
        custom
      ];
    };
  };
}
EOF
log "composed build: target=$TARGET edition=$EDITION arch=$ARCH host=$HOSTNAME pkgs=[$(jq -rc '.packages // []' <<<"$SPEC")]"

# ── Build ────────────────────────────────────────────────────────────────────
CACHE_PATHS=()   # store paths to push to the Nix binary cache (warms later builds)
if [[ "$TARGET" == "iso" ]]; then
  log "nix build install-iso (long step)..."
  nix build --no-link --print-out-paths \
    "$WORK/build#packages.${ARCH}-linux.image" --print-build-logs > "$WORK/outpath" || die "nix build failed"
  RESULT="$(cat "$WORK/outpath")"
  CACHE_PATHS+=("$RESULT")
  # NB: the store path itself ends in `.iso` but is a DIRECTORY (iso/ inside);
  # match files only, first hit, no pipe (avoids matching the dir + SIGPIPE).
  ISO="$(find -L "$RESULT" -type f -name '*.iso' -print -quit)"
  [[ -n "$ISO" ]] || die "no ISO produced"
  NAME="sourceos-${EDITION}-${ARCH}-custom.iso"
  cp "$ISO" "$OUT/$NAME"
  ( cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256" )

elif [[ "$TARGET" == "netboot" ]]; then
  log "nix build netboot kernel + initramfs (long step)..."
  base="$WORK/build#nixosConfigurations.netboot.config.system.build"
  KDIR="$(nix build --no-link --print-out-paths "$base.kernel" --print-build-logs)" || die "kernel build failed"
  CACHE_PATHS+=("$KDIR")
  KERNEL="$(find -L "$KDIR" -type f \( -name 'bzImage' -o -name 'Image' \) -print -quit)"
  [[ -n "$KERNEL" ]] || die "no kernel found in $KDIR"
  RAMDISK_DIR="$(nix build --no-link --print-out-paths "$base.netbootRamdisk")" || die "ramdisk build failed"
  INITRD="$(find -L "$RAMDISK_DIR" -type f -name 'initrd*' -print -quit)"
  [[ -n "$INITRD" ]] || die "no initrd found in $RAMDISK_DIR"
  IPXE="$(nix build --no-link --print-out-paths "$base.netbootIpxeScript")" || die "ipxe build failed"
  # kargs = everything after the kernel path on the ipxe `kernel` line.
  KARGS="$(grep -E '^kernel ' "$(find -L "$IPXE" -type f -print -quit)" | sed -E 's#^kernel +\S+ +##')"
  cp "$KERNEL" "$OUT/kernel"; cp "$INITRD" "$OUT/initrd"
  ( cd "$OUT" && sha256sum kernel initrd > netboot.sha256 )
  KSUM="$(awk '/kernel$/{print $1}' "$OUT/netboot.sha256")"
  ISUM="$(awk '/initrd$/{print $1}' "$OUT/netboot.sha256")"
  cat > "$OUT/netboot-manifest.json" <<JSON
{ "kernel": { "file": "kernel", "sha256": "${KSUM}", "args": "${KARGS}" },
  "initramfs": { "file": "initrd", "sha256": "${ISUM}" } }
JSON
  log "netboot artifacts: kernel + initrd + manifest"
else
  die "unknown TARGET: $TARGET (iso|netboot)"
fi
log "built artifacts in $OUT:"; ls -lh "$OUT"

# ── Upload ───────────────────────────────────────────────────────────────────
if [[ -n "$GCS_PREFIX" ]]; then
  log "uploading to $GCS_PREFIX/ ..."
  if [[ "$TARGET" == "iso" ]]; then
    gsutil cp "$OUT/$NAME" "$OUT/$NAME.sha256" "$GCS_PREFIX/"
    echo "$GCS_PREFIX/$NAME" > "$OUT/artifact-url.txt"
    log "artifact: $GCS_PREFIX/$NAME"
  else
    gsutil cp "$OUT/kernel" "$OUT/initrd" "$OUT/netboot-manifest.json" "$OUT/netboot.sha256" "$GCS_PREFIX/"
    echo "$GCS_PREFIX/netboot-manifest.json" > "$OUT/artifact-url.txt"
    log "netboot base URL: $GCS_PREFIX/"
  fi
fi

# ── Warm the Nix binary cache (best-effort; no-op without NIX_CACHE_* env) ─────
if [[ "${#CACHE_PATHS[@]}" -gt 0 ]]; then
  _selfdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bash "$_selfdir/nix-cache-push.sh" "${CACHE_PATHS[@]}" || true
fi
log "done."
