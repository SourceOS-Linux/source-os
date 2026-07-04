# SourceOS Developer Build IO Governance

Status: proposed
Date: 2026-05-05
Related ADR: `docs/architecture/sourceos-local-index-diagnostics-evidence-fabric.md`

## Executive position

SourceOS must govern not only background daemons but also foreground and agent-triggered developer workloads. Compiler, package-manager, transpiler, bundler, test-runner, and script workloads can generate sustained disk churn while appearing legitimate. That is expected developer behavior, but it must be observable, budgeted, attributable, and cache-aware.

The diagnostic pattern that triggered this note showed language runtimes and compilers exceeding disk-write thresholds while the operating system took no enforcement action. The lesson is not that Rust, Ruby, Node, Python, or other toolchains are suspect. The lesson is that a world-class agentic workstation must distinguish healthy build churn from wasteful, runaway, or misplaced writes.

## Decision

SourceOS will define a developer workload IO governance lane separate from the daemon/indexing governance lane.

The first-class unit is a build/workspace execution envelope:

- repo or workspace root;
- actor: human shell, local agent, CI worker, package manager, editor, test runner, or unknown;
- language/toolchain: Rust, Ruby, Node, Python, Go, Java, C/C++, Nix, container build, or mixed;
- cache roots and artifact roots;
- writable paths;
- expected write budget;
- observed write budget;
- receipt output.

## Why this matters

Build systems legitimately write many files. But unmanaged build writes create four problems:

1. SSD wear and battery drain.
2. Poor developer UX on small machines.
3. Hidden cache explosions in home directories, package stores, and target directories.
4. Agentic execution risk, where automated workers repeatedly rebuild or rewrite artifacts without visible provenance.

SourceOS should make build IO explainable in the same way search/indexing must be explainable.

## Scope

This note covers developer and agent build workloads, including:

- `rustc`, `cargo`, `sccache`, `target/`;
- Ruby, Bundler, gems, generated docs, native extension builds;
- Node, pnpm/yarn/npm caches, Vite/Next/webpack build directories;
- Python, venv, pip, uv, hatch, poetry, wheel caches, mypy/ruff/pytest caches;
- Go module/build caches;
- C/C++ build trees, CMake, Meson, Ninja;
- Nix stores and derivation builds where applicable;
- OCI/container image builds;
- agent-generated code and test loops.

## Non-goals

This note does not ban heavy builds.

This note does not make the host immutable profile responsible for arbitrary project artifacts.

This note does not move language toolchains onto the immutable host.

This note does not replace CI.

## Default policy

SourceOS should route developer writes through declared workspace/cache/artifact locations:

| Workload | Preferred write root | Policy |
|---|---|---|
| Rust | workspace `target/` or configured shared cache | observable and cache-aware |
| Ruby | repo-local bundle path or toolchain cache | observable; avoid hidden global churn |
| Node | repo-local build dirs plus package-manager cache | observable; exclude generated artifacts from search by default |
| Python | repo-local `.venv`, `.pytest_cache`, `.mypy_cache`, wheel cache | observable; no system pip writes |
| Go | configured module/build cache | observable and quota-aware |
| Containers | image/build cache volume | separate from user documents |
| Agent builds | explicit run workspace | strict receipts and cleanup policy |

## Required SourceOS surfaces

### CLI

```bash
sourceos dev status
sourceos dev io top --since 24h
sourceos dev explain --pid <pid>
sourceos dev explain --repo <path>
sourceos dev budget set --repo <path> --write-gb-per-day 10
sourceos dev cache prune --repo <path> --dry-run
sourceos dev receipts query --repo <path> --since 24h
```

### Doctor integration

`doctor.sh --json` should eventually report:

- high write volume by workspace;
- high write volume by toolchain;
- unknown parent process for developer workload;
- writes outside declared workspace/cache roots;
- generated artifacts being indexed unnecessarily;
- repeated build loops;
- low disk headroom near active build workloads.

### Status integration

`sourceos status --json` should expose developer workload warnings without changing existing status shape.

## Build receipts

Minimal build IO receipt:

```json
{
  "schema": "sourceos.dev.io_receipt.v0",
  "observed_at": "2026-05-05T00:00:00Z",
  "actor": {
    "kind": "human-shell|agent|ci|editor|unknown",
    "process": "cargo|rustc|ruby|node|python|go|ninja|podman|unknown",
    "pid": 12345,
    "parent": "terminal|turtleterm|agentplane|unknown"
  },
  "workspace": {
    "path": "/home/user/dev/example",
    "repo": "owner/name",
    "branch": "main"
  },
  "toolchain": {
    "language": "rust|ruby|node|python|go|cpp|mixed|unknown",
    "command": "cargo test"
  },
  "io": {
    "bytes_written": 123456789,
    "duration_seconds": 3600,
    "rate_bytes_per_second": 34293,
    "budget_state": "healthy|constrained|exceeded|quarantined"
  },
  "paths": {
    "declared_artifact_roots": ["target/"],
    "declared_cache_roots": [".cache/sourceos/"],
    "unexpected_write_roots": []
  },
  "action": "observed|warned|throttled|paused|quarantined"
}
```

## Interaction with indexing

Developer artifact roots should be excluded or metadata-only by default:

- `target/`;
- `node_modules/`;
- `.next/`, `dist/`, `build/`, `.turbo/`;
- `.venv/`, `.tox/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`;
- `vendor/bundle/`;
- `.gradle/`, `.m2/`;
- container build caches.

This prevents the local index fabric from multiplying build churn into indexing churn.

## Resource controls

Developer workloads should run under explicit scopes when invoked by SourceOS tools or agents:

- `sourceos-dev.slice` for human developer workloads;
- `sourceos-agent-build.slice` for agent-triggered builds;
- per-repo transient scopes for long-running builds;
- IOWeight and CPUWeight defaults;
- battery-aware warnings;
- optional hard limits for agent lanes;
- receipts for throttling or pause actions.

Human interactive builds should generally warn before hard enforcement. Agentic builds may be throttled or paused automatically because agents can loop.

## Acceptance criteria

A first implementation slice is acceptable when:

1. `sourceos dev io top --since 24h` can identify top write-heavy processes or workspaces.
2. `sourceos dev explain --repo <path>` reports declared cache/artifact roots and observed write state.
3. Common generated artifact directories are metadata-only or excluded from indexing by default.
4. Agent-triggered build lanes produce receipts with actor, workspace, toolchain, and IO budget fields.
5. `doctor.sh --json` warns on repeated build loops, unknown parent process, or writes outside declared roots.
6. No developer IO governance flow sends remote analytics by default.

## Backlog

- Define `sourceos.dev.io_receipt.v0` fixture.
- Add generated-artifact default index exclusions.
- Add `sourceos dev io top` prototype using cgroup/systemd/journald/eBPF-derived summaries where available.
- Add agent build-scope policy for `agentplane` handoff.
- Add cache-prune dry-run support.
- Add workspace-local policy file support, for example `.sourceos/workload-policy.json`.

## Claim discipline

Permitted after this note lands:

- SourceOS recognizes developer-build IO as a first-class governance and observability surface.
- SourceOS will not treat all write-heavy workloads as daemon/index failures.

Not permitted yet:

- complete developer workload governor;
- complete SSD wear model;
- full agent build isolation;
- language-complete cache control.
