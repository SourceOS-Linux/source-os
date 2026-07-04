# SourceOS image signing + provenance — one-time setup

Every built image gets a **self-sovereign** signature + provenance bundle. There
is **no third-party signing authority** — no Apple Developer ID, no Google/Play
app signing, no notarization service. The key is an ed25519 keypair *you*
generate with [`minisign`](https://jedisct1.github.io/minisign/); anyone can
verify a download with the public key alone.

## What each build emits (beside the artifact)

| File | Purpose | Referenced by |
|------|---------|---------------|
| `<artifact>.minisig` | ed25519 detached signature | `OSImage.provenance.signatureRef` |
| `<artifact>.intoto.json` | in-toto Statement (the attestation) | `OSImage.provenance.statementRef` (`urn:srcos:attestation:…`) |
| `<artifact>.slsa.json` | SLSA v1 provenance predicate | `OSImage.provenance.slsaPredicateRef` (`urn:srcos:slsa:…`) |
| `<artifact>.sbom.json` | Nix-closure SBOM (ISO only) | `OSImage.provenance.sbomRef` |
| `<artifact>.osimage.json` | `OSImage` doc, sourceos-spec v2 (ISO only) | — |

Graceful: with **no** signing key the build still emits provenance (just
unsigned — `signatureRef` is omitted) and never fails.

## One-time setup

1. **Generate an unencrypted (CI-friendly) keypair.** `-W` writes a key with no
   password so CI can use it non-interactively:
   ```sh
   minisign -G -W -p sourceos-pub.key -s sourceos-sec.key
   # or, with nix and no minisign installed:
   nix run nixpkgs#minisign -- -G -W -p sourceos-pub.key -s sourceos-sec.key
   ```
   Keep `sourceos-sec.key` secret. **Never commit it** (it belongs with the
   SOPS material under `/etc/sourceos/`, not in git).

2. **Set the signing secret** (repo → Settings → Secrets and variables →
   Actions → Secrets):
   - `SOURCEOS_SIGN_SECRET_KEY` = contents of `sourceos-sec.key`

3. **Publish the public key** so users can verify:
   - Set Actions variable `SOURCEOS_SIGN_PUBKEY` = the last line of
     `sourceos-pub.key` (the `RWQ…` key line).
   - Also host `sourceos-pub.key` on the download site so anyone can check a
     download without trusting us at fetch time.

4. **GCP build lane** (paid tier): the backend passes the same key to the build
   VM as instance metadata `sourceos-sign-secret-key` (plus
   `sourceos-version`, and the cache metadata). Unset → unsigned, same as CI.

## Verifying a download

```sh
# pubkey can be the RWQ… line or a key file; or set $SOURCEOS_SIGN_PUBKEY
scripts/verify-image.sh sourceos-desktop-x86_64.iso "RWQ...the-public-key-line..."
```
Exits 0 only if the signature verifies; it also cross-checks the in-toto
subject digest against the file when `<artifact>.intoto.json` is present.

Raw minisign equivalent:
```sh
minisign -V -P "RWQ...pubkey..." -m sourceos-desktop-x86_64.iso   # needs the .minisig beside it
```

## Notes
- Rotating the key: generate a new pair, update the secret + the published
  pubkey; old downloads stay verifiable with the old pubkey.
- The SLSA predicate currently marks `reproducible: false` and does not attest
  the full build environment/materials — it records the source repo + commit,
  build parameters, and the artifact digest. Tightening to a hermetic,
  reproducible attestation is a later step.
