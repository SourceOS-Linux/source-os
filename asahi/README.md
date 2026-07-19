# SourceOS on Apple Silicon — seamless install

There are two ways onto Apple Silicon. **Use the first.**

## 1. Seamless (recommended) — the Asahi installer

From macOS Terminal:

```sh
curl -fsSL https://get.sourceos.org | sh
```

This runs [`scripts/get-sourceos.sh`](../scripts/get-sourceos.sh), which wraps the
**official Asahi Linux installer** pointed at the SourceOS OS package
([`installer_data.json`](installer_data.json)). The Asahi installer handles
everything that made the manual path painful:

- resizing macOS and creating partitions,
- installing firmware,
- installing and **blessing** the m1n1 + U-Boot bootloader,
- walking you through the one-time recovery (**1TR**) step.

The 1TR step — shut down, hold power until "startup options", authenticate —
is required by Apple's secure boot and **cannot** be automated by anyone
(including Apple's own tooling). The installer tells you exactly when/how.

### How the OS package is produced

`release-images.yml` builds the SourceOS aarch64 system, lays it out as an
Asahi-installer OS package (`esp/` tree + `boot.img` + `root.img`), zips it as
`sourceos-<version>-asahi-arm64.zip`, and uploads it to the GitHub Release.
The CI then templates `installer_data.json` (filling `${VERSION}`, `${TAG}`,
`${PACKAGE_SHA256}`) and uploads that to the same release, so
`releases/latest/download/installer_data.json` always points at the current
package.

The m1n1/U-Boot in the package come from upstream Asahi via the
[`nixos-apple-silicon`](https://github.com/tpwrules/nixos-apple-silicon) flake
input — we do **not** ship a hand-built bootloader on this path.

## 2. Advanced / offline — manual boot bundle

For custom or offline installs, [`scripts/build-m1n1-bundle.sh`](../scripts/build-m1n1-bundle.sh)
produces a versioned boot bundle (stage1 `m1n1.macho`, stage2 `boot.bin`,
`BOOTAA64.EFI`) you bless yourself with `kmutil` from 1TR. This is the path
documented in [`docs/bootstrap/M2_ENROLL.md`](../docs/bootstrap/M2_ENROLL.md)
and verified by [`scripts/preflight.sh`](../scripts/preflight.sh). Most people
should not need it.
