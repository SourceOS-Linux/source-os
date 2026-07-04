# Triune / Exodus runtime bootstrap

- **Status:** Bootstrap / temporary umbrella
- **Date:** 2026-04-15
- **Owners:** mdheller / SociOS-Linux

## Purpose

This document establishes `SourceOS-Linux/source-os` as the **temporary umbrella landing zone** for the SourceOS runtime and enforcement spine **until a dedicated runtime repository exists** under `SourceOS-Linux`.

This repository is not the canonical contract home. Contract objects belong in `SourceOS-Linux/sourceos-spec`. This repository is the temporary implementation home for runtime-oriented components that need to exist now.

## Why this document exists

The current ecosystem contains:

- a strong contract-layer repository (`SourceOS-Linux/sourceos-spec`)
- multiple distro / installer / packaging repositories in `SociOS-Linux`
- but **no dedicated runtime / security control-plane repository** for Triune and Exodus enforcement

Until that runtime repo is created, `SourceOS-Linux/source-os` is the least-wrong landing zone because it identifies itself as the main SociOS Linux SourceOS repository.

## What belongs here now

### Runtime enforcement and control-plane code

- `triune-ctx`
- `cap-checker`
- `triune-anchor`
- `watchdog-validator`
- `quorumd`
- replay packer runtime implementation
- allowlist / exception-ledger enforcement runtime
- egress quarantine orchestration
- runtime audit emission and validator packet generation

### Kernel / host enforcement assets

- cgroup eBPF quarantine programs
- overlay quarantine helpers
- nftables / Unbound / WireGuard orchestration scripts
- sentinel processes for Exodus Reversed detection

### Runtime docs

- operator runbooks
- runtime ADRs that are implementation-specific rather than contract-specific
- integration notes for installer, build, and metapackage repos

## What does not belong here

The following should **not** be treated as native long-term contents of this repo:

- canonical schemas
- OpenAPI / AsyncAPI contract definitions
- semantic overlays
- conformance examples meant for the typed contract layer
- build frontend code
- pure image creation scripts
- installer-only UI code
- student labs / academy materials / founder outreach artifacts

## Recommended temporary tree

```text
source-os/
  docs/
    runtime/
    operator/
    adr/
  runtime/
    triune-ctx/
    cap-checker/
    triune-anchor/
    quorumd/
    watchdog-validator/
  ebpf/
    quarantine/
  scripts/
    quarantine/
    exodus/
    gateway/
  integration/
    installer/
    image-hooks/
    metapackages/
```

## Integration points into other SociOS-Linux repos

### `SociOS-Linux/os`
Use only for:

- image-build inclusion
- default service enablement
- default configuration injection
- image-time hardening hooks

### `SociOS-Linux/installer`
Use only for:

- install-time migration UX
- first-boot onboarding
- Exodus opt-in and migration flow
- posture explanation and consent screens

### `SociOS-Linux/metapackages`
Use only for:

- bundle definitions such as `sourceos-triune`, `sourceos-exodus`, `sourceos-forensics`
- dependency groupings and optional installation surfaces

### `SociOS-Linux/builds`
Use only for:

- surfacing artifact metadata
- release notes / receipt display
- build-channel presentation

## Migration target

The intended end state is:

- **contracts** remain in `SourceOS-Linux/sourceos-spec`
- **runtime implementation** moves into a dedicated `SourceOS-Linux` runtime repository
- `SourceOS-Linux/source-os` then either becomes a thin umbrella / integration repo or retains only SociOS-specific orchestration glue

## Immediate follow-on work

1. Add the runtime subtree shown above.
2. Move initial watchdog / anchor / validator / cap-checker assets into that subtree.
3. Wire package and installer integration through dedicated `integration/` directories rather than mixing concerns.
4. Cut a follow-up issue or ADR proposing the dedicated runtime repository creation.

## Acceptance gates

This bootstrap is considered valid when:

- runtime components land here under a clean subtree,
- contract-layer artifacts remain in `sourceos-spec`,
- and the code can later move to a dedicated runtime repo without schema or path ambiguity.
