# Foreign Volume Linux Estate Upstream Plan

## Goal

Integrate foreign-volume and cross-OS mount policy into a Linux estate in a way that is upstream-friendly, operationally sane, evidence-bearing, and survivable under partial trust.

The design separates four concerns:
1. foreign filesystem classification
2. mount posture and privilege boundaries
3. import and exchange flows
4. recovery and rollback implications

## Linux-native constraints

Release 1 should avoid inventing a bespoke storage daemon or kernel patch set.

Use existing Linux primitives for what they already do well:
- systemd mount and automount units for governed runtime surfaces
- standard kernel mount flags and read-only posture by default
- udev and existing discovery surfaces for partition visibility
- packaging notes and user-space helpers for classification and import workflows

Do not treat foreign host volumes as ordinary mutable service state in Release 1.
Do not normalize risky read-write behavior for foreign system volumes.

## Privilege split

Use separate roles instead of one omnipotent helper:

### Discovery and classification
Unprivileged logic for identifying candidate volumes, filesystems, labels, and likely trust class.

### Mount policy rendering
Controlled logic that maps a classified surface into the allowed Linux mount posture.

### Privileged mount execution
A narrow privileged path for applying mount units or one-shot mounts with the declared safety flags.

### Import and exchange jobs
User-space import/export flows that copy data into governed native storage rather than mutating foreign system volumes in place.

## Estate split

### Workstations and dual-boot devices
Prefer explicit discovery, operator-visible posture, and import-oriented workflows.

### Headless servers and appliances
Prefer policy-declared mounts only; avoid ambient foreign-volume handling except for explicit recovery, migration, or evidence workflows.

## Release-1 scope

### In scope
- foreign filesystem classification
- default read-only posture for foreign system volumes
- explicit exchange-volume handling
- Apple/macOS dual-boot policy mapping
- Linux docs, matrices, packaging notes, and staged workstreams
- evidence-bearing import and rollback guidance

### Out of scope
- automatic read-write support for risky foreign system filesystems
- bespoke kernel filesystems
- silent cross-OS mutation of boot-adjacent assets
- broad container exposure of foreign host volumes

## Repo placement in `source-os`

- `docs/storage/` — design and rollout docs
- `linux/packaging/` — packaging notes and future package split stubs
- future Linux-facing templates under `linux/` only after the policy matrix stabilizes

Shared normative standards remain in `SocioProphet/socioprophet-standards-storage`, not here.
