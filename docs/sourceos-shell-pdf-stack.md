# sourceos-shell PDF stack note

This note tracks the Linux realization scaffold for the PDF lane during the `sourceos-shell` rollout.

## Current Linux-facing surfaces

The Linux realization currently carries service scaffolds for:

- `sourceos-pdf-secure`
- `sourceos-docd`

These are represented both as systemd unit files under `linux/systemd/` and as service declarations in `modules/nixos/sourceos-shell/default.nix`.

The Linux realization now also carries a machine-facing config surface at:

- `/etc/sourceos-shell/pdf-stack.json`

This config captures the relationship between the derive lane and the secure/sign-validate lane while the runtime repo is still absent.

## Intent

This is the Linux realization slice of the broader PDF lane tracked in `#93`.

The future `SourceOS-Linux/sourceos-shell` runtime repo should own the actual PDF derivation, signing, validation, and viewing behavior. `source-os` should only keep the host/service realization and validation hooks.

## Validation scaffold

The current Linux realization adds dedicated contract-style checks at:

- `tests/sourceos-shell-pdf-stack-contract.nix`
- `tests/sourceos-shell-pdf-config-contract.nix`

These checks verify that the PDF-related runtime scaffolds, module hooks, and realized config surface remain present and aligned.
