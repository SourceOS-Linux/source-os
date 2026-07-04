# Foreign Filesystem Policy Matrix

## Rule of thumb

If a foreign volume can be handled by read-only import plus copy-in to governed native storage, do that.

## Filesystem classes

| Filesystem / surface | Default class | Default posture | Linux realization notes |
| --- | --- | --- | --- |
| APFS host system/data volumes | foreign system volume | read-only import only | treat as foreign system state; do not use as mutable runtime state |
| HFS+ journaled volumes | foreign system volume | read-only import only | treat journaled host volumes as import-only by default |
| exFAT exchange partition | exchange volume | read-write only for exchange workflows | never use for substrate-sensitive state, audit stores, or host runtime state |
| ext4/xfs/btrfs from another Linux host or distro | foreign Linux volume | read-only by default | allow read-write only when the trust domain and ownership model are explicitly declared |
| boot-adjacent foreign assets | substrate-sensitive import | read-only import only | mutations require privileged substrate operations and explicit recovery intent |

## Required default flags

### Foreign system volumes

Default posture SHOULD be equivalent to:
- `ro`
- `nodev`
- `nosuid`
- `noexec`

### Exchange volumes

Default posture SHOULD preserve:
- `nodev`
- `nosuid`

Read-write MAY be allowed for explicit exchange workflows.
Executable use SHOULD remain disabled unless a declared workload requires it and the trust model is documented.

## Apple dual-boot rule

On Apple dual-boot devices:
- macOS system and data volumes are foreign system volumes
- shared exchange partitions are separate exchange surfaces, not extensions of the host runtime
- recovery and boot-adjacent foreign assets are substrate-sensitive imports

## Container rule

Foreign system volumes are forbidden in ordinary rootless container mounts by default.
Exchange volumes MAY be bound into explicit import/export jobs where the policy class is declared.

## Evidence rule

Every governed foreign-volume workflow SHOULD emit enough evidence to reconstruct:
- discovered filesystem type
- assigned class
- resulting mount posture
- any explicit read-write exception
