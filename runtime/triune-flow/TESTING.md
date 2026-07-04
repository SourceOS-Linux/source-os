# triune-flow testing notes

## Smoke test

The crate includes `tests/smoke.rs`, which:

- runs the `triune-flow` binary
- parses the emitted JSON
- loads `output.sample.json`
- compares stable fields such as plane, grant id, isolation mode, and majority verdict
- asserts that anchor hashes retain the expected `sha256:` prefix

## Run locally

```bash
cd runtime/triune-flow && cargo test
```

## Why the test is shape-based

Some values in the integration flow are expected to vary at runtime, especially:

- generated call IDs
- append-only anchor roots
- temporary file paths

The smoke test therefore validates the stable contract shape and selected invariants rather than exact full-payload equality.
