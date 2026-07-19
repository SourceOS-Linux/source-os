# sourceos-shell service graph note

The Linux realization layer currently models the `sourceos-shell` runtime as a four-service graph:

- `sourceos-shell`
- `sourceos-router`
- `sourceos-pdf-secure`
- `sourceos-docd`

These services are grouped by the `sourceos-shell.target` scaffold.

## Intent

This target is a Linux realization placeholder that captures the expected runtime grouping before the actual product/runtime repo exists.

## Validation scaffold

The current Linux realization adds a dedicated contract-style check at:

- `tests/sourceos-shell-service-graph-contract.nix`

This check verifies that:

- `sourceos-shell.target` exists
- the four runtime scaffold services are grouped beneath that target
- the Nix module expresses the target and `partOf` relationships consistently

## Follow-on

Once `SourceOS-Linux/sourceos-shell` exists, the placeholder ExecStart values should be replaced with real package/service paths and the current scaffold checks should be upgraded into actual runtime/service-graph checks.
