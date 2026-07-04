# Runtime workspace build guide

This runtime subtree now has a Cargo workspace root at `runtime/Cargo.toml`.

## Build everything

```bash
cd runtime && cargo build --workspace
```

## Run tests

```bash
cd runtime && cargo test --workspace
```

## Run examples

### Watchdog trigger -> quarantine -> anchor packet

```bash
cd runtime && cargo run -p watchdog-validator --example triune_flow
```

### Quorum vote aggregation

```bash
cd runtime && cargo run -p quorumd --example quorum_votes
```

### Anchor CLI

```bash
cd runtime && cargo run -p triune-anchor --bin triune-anchor -- /tmp/triune.ndjson telemetry urn:srcos:session:s001
```

## Current workspace members

- `triune-ctx`
- `cap-checker`
- `triune-anchor`
- `watchdog-validator`
- `quorumd`

## Current status

This is still a bootstrap workspace. It is intended to prove shape, crate boundaries, and the trigger -> anchor -> quorum flow before the runtime is moved into a dedicated `SourceOS-Linux` repository.
