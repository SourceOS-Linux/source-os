# Storage Linux Estate Integration

This directory carries the Linux-native realization material for storage and mount-surface work inside `source-os`.

Placement rule:
- Linux estate realization lives here.
- Shared storage and mount-surface standards live in `SocioProphet/socioprophet-standards-storage`.
- Typed resources and shared vocabulary should live in `SourceOS-Linux/sourceos-spec`.
- Control-plane lifecycle and promotion semantics remain outside this directory unless they directly affect Linux storage realization.

Contents:
- `foreign_volume_linux_estate_upstream_plan.md` — Linux-native integration plan and role split for foreign-volume handling
- `foreign_filesystem_policy_matrix.md` — filesystem classes, default posture, and Linux policy mapping
- `upstream_workstreams.md` — staged upstream workstream plan

Companion Linux-facing templates and packaging notes should live under `linux/` once the policy matrix is stable enough to realize concretely.
