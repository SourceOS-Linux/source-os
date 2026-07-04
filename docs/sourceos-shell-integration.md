# sourceos-shell Linux realization note

`sourceos-shell` is the primary product/runtime repository for the SourceOS shell application stack.

This repository, `source-os`, carries the Linux realization surfaces required to run that shell on Linux hosts and images.

## What belongs here

- desktop entries
- systemd user or host services
- Nix/NixOS modules
- profile wiring
- machine-level integration hooks

## What does not belong here

- shared schema canon
- product/runtime UI code
- ad hoc control-plane semantics

## Upstream relationship

- `SourceOS-Linux/sourceos-shell` — product/runtime
- `SourceOS-Linux/sourceos-spec` — shared contracts
- `SourceOS-Linux/source-os` — Linux realization
- `SociOS-Linux/albert` — temporary launcher bridge only
