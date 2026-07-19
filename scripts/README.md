# Runtime scripts

This directory is reserved for runtime helper scripts used during the Triune / Exodus bootstrap phase.

## Planned contents

- BPF key helpers for map updates
- quarantine-entry wrappers
- allowlist update helpers
- gateway / WireGuard / nftables orchestration
- Exodus Reversed detection helpers

## Safety note

Scripts in this subtree are privileged or operational in nature and must be paired with:

- audit anchoring
- capability checks where mutation is possible
- validator review for exceptional operations

## Temporary status

This subtree exists in `SourceOS-Linux/source-os` as a bootstrap landing zone until a dedicated runtime repository exists under `SourceOS-Linux`.
