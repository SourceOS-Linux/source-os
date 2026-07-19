#!/usr/bin/env bash
# sign-and-provenance.sh — Self-sovereign signing + provenance for a built image.
#
# Produces, alongside a built artifact:
#   <name>.minisig        ed25519 detached signature (minisign, self-managed key)
#   <name>.intoto.json    in-toto Statement (the attestation; OSImage.statementRef)
#   <name>.slsa.json      SLSA v1 provenance predicate (OSImage.slsaPredicateRef)
#   <name>.sbom.json      Nix-closure SBOM (OSImage.sbomRef)              [iso only]
#   <name>.osimage.json   OSImage doc conforming to sourceos-spec v2      [iso only]
#
# NO third-party signing authority — no Apple Developer ID, no Google/Play
# signing, no notarization. The signing key is an ed25519 keypair you generate
# yourself with `minisign -W` (see docs/SIGNING_SETUP.md). Verification is
# anyone-can-check with the public key.
#
# Graceful by design: with no SOURCEOS_SIGN_SECRET_KEY the artifact is left
# unsigned but provenance is still emitted (signatureRef omitted). This script
# never fails the build — it always exits 0.
#
# Env:
#   OUT                       output dir holding the artifact(s)        (required)
#   TARGET                    iso | netboot                             (default iso)
#   EDITION                   desktop | server | edge                   (default desktop)
#   ARCH                      x86_64 | aarch64                          (default x86_64)
#   NAME                      iso filename in $OUT                      (iso target)
#   BUILD_ID, BUILD_UID       build/user identifiers (for URNs)
#   HOSTNAME_                 composed hostname (informational)
#   VERSION                   os version, e.g. 26.11                    (default 0.0.0-dev)
#   SOURCE_REV                source commit (default $GITHUB_SHA or unknown)
#   SOURCE_REPO               source repo URL
#   STORE_PATHS               space-separated Nix store paths (for SBOM closure)
#   GCS_PREFIX                if set, *Ref fields that can be URLs point here
#   SOURCEOS_SIGN_SECRET_KEY  minisign secret key contents (unencrypted, -W)  [secret]
#   SOURCEOS_SIGN_PUBKEY      minisign public key line (informational ref)
set -uo pipefail   # NB: no -e; this script is best-effort and must not fail builds.

OUT="${OUT:-out}"
TARGET="${TARGET:-iso}"
EDITION="${EDITION:-desktop}"
ARCH="${ARCH:-x86_64}"
VERSION="${VERSION:-0.0.0-dev}"
SOURCE_REV="${SOURCE_REV:-${GITHUB_SHA:-unknown}}"
SOURCE_REPO="${SOURCE_REPO:-https://github.com/SourceOS-Linux/source-os}"
SPEC_VERSION="2.1.0"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log() { printf '[sign-prov] %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || { log "jq missing — skipping provenance"; exit 0; }

# minisign may not be on PATH; fall back to `nix run` when nix is present.
minisign_run() {
  if command -v minisign >/dev/null 2>&1; then minisign "$@"
  elif command -v nix >/dev/null 2>&1; then nix run nixpkgs#minisign -- "$@"
  else return 127; fi
}

# Map edition → OSImage.hostProfile (substrate persona, NOT a cybernetic role).
case "$EDITION" in
  desktop) HOST_PROFILE=workstation;;
  server)  HOST_PROFILE=vm-base;;
  edge)    HOST_PROFILE=edge-appliance;;
  *)       HOST_PROFILE=vm-base;;
esac

# Lowercase, URN-safe local id: <edition>-<arch>-<build|rev short>.
_raw_id="${BUILD_ID:-${SOURCE_REV}}"
LOCAL_ID="$(printf '%s' "${EDITION}-${ARCH}-${_raw_id}" \
  | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-' | sed -E 's/-+/-/g; s/^-+//; s/-+$//')"
[[ -n "$LOCAL_ID" ]] || LOCAL_ID="build"

# ── Per-artifact signing ───────────────────────────────────────────────────────
# Signs a single file (best-effort). Echoes the .minisig path on success.
sign_file() {
  local f="$1"
  [[ -n "${SOURCEOS_SIGN_SECRET_KEY:-}" ]] || return 1
  local keyf; keyf="$(mktemp)"
  printf '%s\n' "$SOURCEOS_SIGN_SECRET_KEY" > "$keyf"
  # Unencrypted (-W) key → no password prompt; </dev/null guards against a hang
  # if an encrypted key was supplied by mistake.
  if minisign_run -S -s "$keyf" -m "$f" -x "$f.minisig" \
       -c "sourceos $LOCAL_ID" -t "sourceos:$LOCAL_ID" </dev/null >/dev/null 2>&1; then
    rm -f "$keyf"; printf '%s' "$f.minisig"; return 0
  fi
  rm -f "$keyf"; return 1
}

digest_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

# Collect the subject files for this target.
SUBJECTS=()
if [[ "$TARGET" == "iso" ]]; then
  [[ -n "${NAME:-}" && -f "$OUT/$NAME" ]] && SUBJECTS+=("$OUT/$NAME")
else
  for f in kernel initrd; do [[ -f "$OUT/$f" ]] && SUBJECTS+=("$OUT/$f"); done
fi
[[ "${#SUBJECTS[@]}" -gt 0 ]] || { log "no artifacts to attest in $OUT — skipping"; exit 0; }

# Sign each subject; build the in-toto subject[] array as we go.
SIGNED=0
SUBJECT_JSON="$(jq -n '[]')"
for f in "${SUBJECTS[@]}"; do
  d="$(digest_of "$f")"
  base="$(basename "$f")"
  if sig="$(sign_file "$f")"; then SIGNED=1; log "signed $base"; else log "unsigned $base (no key / minisign unavailable)"; fi
  SUBJECT_JSON="$(jq --arg n "$base" --arg d "$d" '. + [{name:$n, digest:{sha256:$d}}]' <<<"$SUBJECT_JSON")"
done

PRIMARY="${SUBJECTS[0]}"
PRIMARY_DIGEST="$(digest_of "$PRIMARY")"
PRIMARY_BASE="$(basename "$PRIMARY")"

STATEMENT_URN="urn:srcos:attestation:${LOCAL_ID}"
SLSA_URN="urn:srcos:slsa:${LOCAL_ID}"

# signatureRef / sbomRef: URLs when uploading, else relative filenames.
ref_for() { if [[ -n "${GCS_PREFIX:-}" ]]; then printf '%s/%s' "$GCS_PREFIX" "$1"; else printf '%s' "$1"; fi; }

# ── SLSA v1 provenance predicate ───────────────────────────────────────────────
SLSA_FILE="$OUT/${PRIMARY_BASE}.slsa.json"
jq -n \
  --arg repo "$SOURCE_REPO" --arg rev "$SOURCE_REV" --arg now "$NOW" \
  --arg edition "$EDITION" --arg arch "$ARCH" --arg target "$TARGET" \
  --arg hostname "${HOSTNAME_:-}" --arg builder "sourceos/build-custom-image" \
  '{
     buildType: "https://schemas.srcos.ai/buildtypes/nix-image/v1",
     builder: { id: $builder },
     invocation: {
       configSource: { uri: $repo, digest: { gitCommit: $rev } },
       parameters: { edition: $edition, arch: $arch, target: $target, hostname: $hostname }
     },
     metadata: {
       buildStartedOn: $now,
       completeness: { parameters: true, environment: false, materials: false },
       reproducible: false
     },
     materials: [ { uri: $repo, digest: { gitCommit: $rev } } ]
   }' > "$SLSA_FILE" 2>/dev/null && log "wrote $(basename "$SLSA_FILE")"

# ── in-toto attestation statement (wraps the SLSA predicate) ───────────────────
STATEMENT_FILE="$OUT/${PRIMARY_BASE}.intoto.json"
jq -n \
  --argjson subject "$SUBJECT_JSON" \
  --slurpfile predicate "$SLSA_FILE" \
  --arg urn "$STATEMENT_URN" \
  '{
     "_type": "https://in-toto.io/Statement/v1",
     "id": $urn,
     "subject": $subject,
     "predicateType": "https://slsa.dev/provenance/v1",
     "predicate": $predicate[0]
   }' > "$STATEMENT_FILE" 2>/dev/null && log "wrote $(basename "$STATEMENT_FILE")"

# ── SBOM (Nix closure of the build store paths) — iso only ─────────────────────
SBOM_REF=""
if [[ "$TARGET" == "iso" && -n "${STORE_PATHS:-}" ]] && command -v nix >/dev/null 2>&1; then
  SBOM_FILE="$OUT/${PRIMARY_BASE}.sbom.json"
  WORK_SBOM="$(mktemp)"
  # shellcheck disable=SC2086
  if nix path-info --json -r $STORE_PATHS > "$WORK_SBOM" 2>/dev/null \
     && jq -n --slurpfile c "$WORK_SBOM" --arg now "$NOW" --arg name "$PRIMARY_BASE" \
        '{ bomFormat:"SourceOS-NixClosure", specVersion:"1.0", metadata:{timestamp:$now, component:{name:$name}},
           components: ($c[0] | (if type=="object" then (to_entries|map(.value)) else . end)
             | map({ "store-path": (.path // .key // ""), narHash: (.narHash // ""), narSize: (.narSize // 0) })) }' \
        > "$SBOM_FILE" 2>/dev/null; then
    SBOM_REF="$(ref_for "$(basename "$SBOM_FILE")")"
    log "wrote $(basename "$SBOM_FILE")"
  fi
fi

# ── OSImage document (sourceos-spec v2) — iso target only ──────────────────────
# Netboot kernel/initrd are not a single bootable "image artifact" in the schema's
# artifact enum, so OSImage is emitted for the downloadable ISO only.
if [[ "$TARGET" == "iso" ]]; then
  SIG_REF=""
  [[ "$SIGNED" -eq 1 ]] && SIG_REF="$(ref_for "${PRIMARY_BASE}.minisig")"
  OSIMAGE_FILE="$OUT/${PRIMARY_BASE}.osimage.json"
  prov="$(jq -n --arg s "$STATEMENT_URN" --arg p "$SLSA_URN" --arg sb "$SBOM_REF" --arg sg "$SIG_REF" \
     '{statementRef:$s, slsaPredicateRef:$p}
        + (if $sb != "" then {sbomRef:$sb} else {} end)
        + (if $sg != "" then {signatureRef:$sg} else {} end)')"
  jq -n \
    --arg id "urn:srcos:osimage:${LOCAL_ID}" \
    --arg specVersion "$SPEC_VERSION" \
    --arg shortId "so1-${HOST_PROFILE}" \
    --arg hostProfile "$HOST_PROFILE" \
    --arg arch "$ARCH" \
    --arg edition "$EDITION" \
    --arg version "$VERSION" \
    --arg rev "$SOURCE_REV" \
    --arg repo "$SOURCE_REPO" \
    --arg created "$NOW" \
    --argjson provenance "$prov" \
    '{
       id: $id,
       type: "OSImage",
       specVersion: $specVersion,
       shortId: $shortId,
       family: "sourceos",
       epoch: 1,
       hostProfile: $hostProfile,
       artifact: "iso",
       architecture: $arch,
       osRelease: {
         ID: "sourceos",
         VERSION_ID: $version,
         IMAGE_ID: ("sourceos-" + $edition),
         IMAGE_VERSION: $version
       },
       ociAnnotations: {
         "org.opencontainers.image.version": $version,
         "org.opencontainers.image.revision": $rev,
         "org.opencontainers.image.source": $repo,
         "org.opencontainers.image.created": $created,
         "com.socioprophet.os.channel": "custom"
       },
       substrateCapabilities: [ "content-addressed-store", "self-update", "nlboot-capable" ],
       provenance: $provenance
     }' > "$OSIMAGE_FILE" 2>/dev/null && log "wrote $(basename "$OSIMAGE_FILE")"
fi

log "provenance complete (signed=$SIGNED) for $PRIMARY_BASE"
exit 0
