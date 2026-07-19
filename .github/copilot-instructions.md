# Copilot coding-agent instructions — source-os

## Guiding principle

Use the GitHub issue body as the source of truth for every task.
Do not infer scope beyond what the issue explicitly states.

## Workflow rules

1. **Issue-first.** Every change must trace back to an open GitHub issue in this
   repository. Do not open PRs without a corresponding issue.
2. **Bounded PRs.** One PR addresses one issue. Do not bundle unrelated fixes,
   refactors, or improvements into the same PR.
3. **Validation evidence required.** Every PR body must include the exact
   commands that were run, their pass/fail output, and any known gaps.
4. **No unrelated changes.** Do not modify files that are not directly required
   to satisfy the acceptance criteria in the issue.

## High-risk paths — mandatory human review before merge

Changes touching any of the following paths require an explicit maintainer
review and approval before merging:

| Path / pattern | Risk category |
|---|---|
| `hosts/` | Host-role mutation |
| `images/` | Image build definitions |
| `profiles/` | NixOS profile definitions |
| `modules/` | Shared NixOS modules |
| `builders/` | Builder configuration |
| `flake.nix`, `flake.lock` | Flake root / dependency lock |
| `scripts/install*`, `scripts/enable*` | Install / provisioning scripts |
| `*.service`, `*.timer`, `*.preset` | systemd units |
| `ebpf/` | eBPF programs (kernel boundary) |
| `runtime/` | Runtime admission and cap-checker |
| `.github/workflows/` | CI/CD workflows |
| `configs/` | Host and channel configuration |
| `channels/` | Channel promotion config |

## SourceOS-specific boundaries

- **Boot / install / recovery paths** (`hosts/`, `images/`, scripts that write
  to `/etc/` or `/boot/`): changes must be syntax-checked and smoke-tested
  before the PR is opened. Claim no production readiness unless a full
  integration test has been run.
- **Host mutation** (`profiles/`, `modules/`): Nix expressions must evaluate
  cleanly (`nix flake check` or equivalent) before merging.
- **Workflows** (`.github/workflows/`): only modify if strictly required to
  validate the work in scope. Document the reason in the PR body.
- **Runtime admission** (`runtime/`, `ebpf/`): capability and policy changes
  must include a quorum/anchor smoke test result.

## PR body template

```
## What changed
<!-- Short description of the change -->

## Commands run
<!-- Exact commands, in order -->

## Output summary
<!-- pass / fail, truncated where long -->

## Known gaps
<!-- Anything incomplete, untested, or deferred -->

## Blocked on
<!-- External dependencies or decisions needed -->
```
