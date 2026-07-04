# workstation-contracts Bootstrap Outline

## Purpose
This note defines the minimum intended shape for a future `SociOS-Linux/workstation-contracts` repository.

The goal is to keep generic runner / adapter / workspace / CI / package-catalog logic out of Apple Silicon bootstrap repositories while still making the Apple Silicon lane a first-class consumer.

## Proposed responsibility

`workstation-contracts` should be the generic execution substrate for:
- contract runner
- backend adapters
- workspace manifests and materialization
- CI/bootstrap fixture harnesses
- package catalog / mirror logic
- reproducible workstation and build lanes across platforms

It should **consume**:
- `SourceOS-Linux/sourceos-spec` for normative schemas/contracts
- `SourceOS-Linux/asahi-installer` for Apple Silicon bootstrap flow
- future `SourceOS-Linux/asahi-installer-data` for Apple Silicon install metadata

## Initial repository shape

```text
workstation-contracts/
  docs/
    CHARTER.md
    WORKSPACE_MODEL.md
  runner/
  adapters/
  fixtures/
  schemas/
  workspace/
  curation/
  ci/
```

## Expected top-level concerns

### `runner/`
Thin contract-runner entrypoint and orchestration logic.

### `adapters/`
Backend adapters for pixi/conda, brew, nix, apt/dnf, source-build, and platform lanes.

### `fixtures/`
Compatibility vectors for runner ↔ adapter IPC and lane behaviors.

### `schemas/`
Implementation-side validation artifacts derived from normative contracts.

### `workspace/`
Manifest/materialization logic for the composable workspace model.

### `curation/`
Package catalog, pins, hashes, provenance, and mirror policy.

### `ci/`
Workflow templates and enforcement for lock-driven, evidence-emitting CI lanes.

## Rule

If a change is generic runner/adapters/workspace/package orchestration, it belongs here.
If a change is Apple Silicon install/recovery/bootstrap logic, it belongs in `asahi-installer`.
If a change is normative schema/compatibility contract, it belongs in `sourceos-spec`.
