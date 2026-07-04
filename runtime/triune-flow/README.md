# triune-flow

Standalone integration crate for the temporary SourceOS runtime umbrella.

## Purpose

This crate composes the currently landed runtime crates without requiring us to rewrite their manifests in-place:

- `triune-ctx`
- `cap-checker`
- `triune-anchor`
- `watchdog-validator`
- `quorumd`

## What it proves

- a Triune context can be stamped and verified
- a capability grant can authorize a runtime operation
- a quarantine plan and anchor payload can be produced
- an audit record can be appended
- validator votes can be aggregated into a majority verdict

## Current entrypoint

- `src/main.rs` — minimal end-to-end integration example

## Temporary status

This crate exists to avoid fighting the current repo shape while upstream is moving. Once a dedicated `SourceOS-Linux` runtime repository exists, this integration flow should be absorbed into that runtime workspace directly.
