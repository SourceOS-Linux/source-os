# Apple Dual-Boot Validation Notes

## Purpose

This note records the validation posture for Apple dual-boot devices in the storage tranche.

It complements the foreign-filesystem policy matrix by making the operator-facing validation questions explicit.

## Validation questions

### 1. Discovery

The realization should be able to answer:
- which visible partitions are macOS system and data volumes,
- which visible partitions are explicit exchange surfaces,
- which visible partitions are boot-adjacent or recovery-relevant,
- and which filesystems are only candidates for read-only import.

### 2. Default posture

The validation path should confirm that:
- macOS system and data volumes are classified as foreign system volumes,
- exchange surfaces remain separate from the SourceOS runtime,
- boot-adjacent foreign assets are treated as substrate-sensitive imports.

### 3. Mount behavior

The validation path should confirm that:
- foreign system volumes default to read-only posture,
- required safety flags remain visible,
- and no ordinary rootless container path receives a forbidden foreign system mount by default.

### 4. Import and exchange workflow

The validation path should confirm that:
- import workflows prefer copy-in to governed native storage,
- exchange workflows are explicit,
- and evidence is sufficient to reconstruct the resulting class and posture.

## Release-1 rule

Release 1 should prioritize operator-visible correctness and safe posture over broad automation.

Silent normalization of risky in-place mutation is out of scope.
