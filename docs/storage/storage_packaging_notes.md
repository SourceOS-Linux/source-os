# Storage Packaging Notes

## Purpose

This note records the likely Linux-facing runtime surfaces for foreign-volume and cross-OS mount realization work.

It is intentionally packaging-oriented and does not yet prescribe a concrete generator, daemon, or mount-unit layout.

## Recommended runtime surfaces

- `/etc/sourceos/storage/` — operator-visible storage and mount policy declarations
- `/usr/libexec/sourceos/` — helper entry points for classification, import, and policy rendering
- `/usr/lib/systemd/system/` — optional service or one-shot unit files if later justified
- `/usr/share/doc/sourceos/storage/` — operator guidance and recovery notes

## Recommended package split for later realization

- `sourceos-storage-policy`
- `sourceos-storage-import`
- `sourceos-storage-systemd` (optional)
- `sourceos-storage-udisks` (optional)
- `sourceos-storage-selinux` (optional)
- `sourceos-storage-apparmor` (optional)

## Rule of thumb

- keep foreign-volume discovery and import in user space where practical
- avoid normalizing risky foreign-filesystem write paths into the base substrate package
- keep substrate-sensitive recovery behavior distinct from ordinary exchange workflows
