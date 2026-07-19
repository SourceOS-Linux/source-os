# AGENTS — source-os operating instructions

## Cardinal rule

One repo, one issue, one PR.

Every automated or assisted change in this repository must be backed by a
single open GitHub issue and delivered in a single, focused pull request.

## Scope rules

- **Issue-first.** Do not start work without an open issue that explicitly
  describes the acceptance criteria.
- **Bounded scope.** Implement only what the issue acceptance criteria require.
  Do not add improvements, refactors, or housekeeping unless the issue asks
  for them.
- **No cross-repo side-effects.** Changes must stay inside this repository.
  Do not open PRs or push commits to other repositories as a side effect.

## Validation evidence

Every PR body must contain:

1. The exact commands run (copy-paste, not paraphrased).
2. Pass/fail output for each command (truncate long output but preserve the
   result line).
3. Known gaps — anything not tested, deferred, or out of scope.
4. Blocked items — external decisions or dependencies needed before the work
   can be completed.

## High-risk path rules

The following paths carry elevated risk. Changes here require explicit
maintainer approval before merge and must include validation evidence:

- `hosts/` — machine-role definitions (host mutation risk)
- `images/` — image build definitions
- `profiles/` — NixOS profiles
- `modules/` — shared NixOS modules
- `builders/` — builder configuration
- `flake.nix`, `flake.lock` — flake root and dependency lock
- `scripts/install*`, `scripts/enable*` — install / provisioning
- `*.service`, `*.timer`, `*.preset` — systemd units
- `ebpf/` — eBPF / kernel boundary
- `runtime/` — runtime admission and capability checker
- `.github/workflows/` — CI/CD pipelines
- `configs/`, `channels/` — host and channel configuration

### Boot / install / recovery

Scripts and configs that write to `/etc/` or `/boot/`, or that are invoked
during OS installation or recovery, must be:

- syntax-checked (`bash -n` or `shellcheck`) before the PR is opened;
- smoke-tested in a non-production environment;
- documented with pass/fail evidence in the PR body.

Do not claim production readiness unless a full integration test result is
included.

### Host mutation

Nix expressions (`profiles/`, `modules/`, `flake.nix`) must evaluate cleanly
(`nix flake check` or equivalent) before the PR is opened.

### Workflows

Do not modify `.github/workflows/` unless the issue explicitly requires it.
If a workflow change is required, state the reason in the PR body.

### Runtime admission

Changes to `runtime/` or `ebpf/` must include a quorum/anchor smoke-test
result demonstrating that capability checks and policy enforcement still pass.

## Non-goals

The following are explicitly out of scope for agents operating in this repo:

- Modifying workstation implementation files beyond what the issue requires.
- Changing package manifests unless the issue requires it.
- Claiming production readiness without full integration evidence.
- Touching other repositories.
