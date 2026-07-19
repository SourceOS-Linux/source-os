# SourceOS runtime scaffold

This subtree is the temporary implementation home for the Triune / Exodus runtime and enforcement spine.

It exists here in `SourceOS-Linux/source-os` only until a dedicated runtime repository is created under `SourceOS-Linux`.

## Intended layout

```text
runtime/
  triune-ctx/
  cap-checker/
  triune-anchor/
  quorumd/
  watchdog-validator/
```

## Scope

Runtime-only artifacts belong here:

- watchdog / validator runtime
- replay packer implementation
- audit anchoring implementation
- capability enforcement middleware
- runtime policy application
- exception-ledger enforcement
- operator runbooks and implementation-specific ADRs

## Non-goals

This subtree is not the canonical home for:

- schemas
- OpenAPI / AsyncAPI contracts
- semantic overlays
- typed examples

Those remain in `SourceOS-Linux/sourceos-spec`.

## Bootstrap sequence

1. Add runtime crates / modules under the subtree above.
2. Land eBPF quarantine assets under `ebpf/`.
3. Land operational scripts under `scripts/`.
4. Wire package / installer / image integration through dedicated integration directories rather than mixing concerns.
