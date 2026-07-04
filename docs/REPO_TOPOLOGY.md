# SourceOS / SociOS Repository Topology

## Purpose
This note records the current intended split of responsibilities across the ecosystem so that Apple Silicon bootstrap, contracts, and generic build tooling do not get collapsed into the wrong repository.

## Topology

### `SourceOS-Linux/sourceos-spec`
Canonical contract layer:
- schemas
- IPC contracts
- compatibility rules
- ADRs

### `SourceOS-Linux/asahi-installer`
Apple Silicon bootstrap lane:
- macOS-side machine checks
- APFS / partition orchestration
- stub macOS / recovery handoff
- IPSW and firmware preparation
- installer packaging

### `SourceOS-Linux/asahi-u-boot`
Apple Silicon boot-chain lane.

### Proposed `SourceOS-Linux/asahi-installer-data`
Apple Silicon installer metadata and payload catalog.

### Proposed `SociOS-Linux/workstation-contracts`
Generic runner / adapters / workspace / CI / package catalog implementation.

### Existing downstream SociOS-Linux repos
Consume outputs:
- `metapackages`
- `default-settings`
- `dock`
- `stylesheet`
- `icons`
- related desktop and installer consumers

## Rule of thumb
- If it is required to bootstrap Linux onto Apple Silicon from macOS / recovery, it belongs in the Asahi installer lane.
- If it is a normative compatibility or schema rule, it belongs in `sourceos-spec`.
- If it is generic runner / adapter / workspace / package orchestration, it belongs in a separate implementation repo rather than in the Apple Silicon bootstrap repo.
