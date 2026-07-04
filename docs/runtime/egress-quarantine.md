# Egress quarantine (operator runbook)

This document describes the no-restart quarantine path for a live process using cgroup eBPF hooks.

## Goal

Move a running process into a restricted cgroup and deny new outbound network activity by default, permitting only tightly scoped allowlist entries for audited DNS / attest / audit flows.

## Components

- `ebpf/quarantine/egress_allowlist.bpf.c`
- `ebpf/quarantine/Makefile`
- helper scripts under `scripts/`
- watchdog / validator runtime in `runtime/watchdog-validator/`

## Intended flow

1. Detect policy drift, attestation failure, or egress violation.
2. Resolve the target process set.
3. Create or reuse a quarantine cgroup.
4. Attach cgroup eBPF programs that default to deny.
5. Add only the minimum required allowlist entries.
6. Emit an audit anchor and a quarantine receipt.
7. Hand off to validator quorum for release or termination.

## Key caveats

- cgroup sock_addr hooks block new connects and UDP sends; established flows may require an additional cut step.
- child-process containment must be enforced so forks remain inside the quarantine cgroup.
- allowlist mutations must be audited and eventually capability-gated.

## Contract linkage

Each quarantine action should emit or reference:

- `QuarantineReceipt`
- `AuditAnchorRecord`
- `ValidatorDecision`
- `ReplayEnvelope` when a replay pack is produced

## Temporary status

This runbook documents the runtime bootstrap state in `SourceOS-Linux/source-os` until a dedicated runtime repository exists.
