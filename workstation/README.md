# Workstation profiles

This directory contains **implementation artifacts** for SourceOS workstation profiles.

A workstation profile is a versioned bundle of:

- Package manifests (SYSTEM vs USER vs TOOLBOX layers)
- Shell/terminal defaults (keyboard-first)
- Desktop defaults (GNOME) where applicable
- Launcher actions (Albert) where applicable
- Validation probes (`doctor`)

Profiles are stored under:

- `workstation/profiles/<profile-name>/`

The CLI entrypoint is:

- `workstation/bin/sourceos`

Design/RFC source of truth lives in `SociOS-Linux/enhancements`, while typed contract boundaries live in `SourceOS-Linux/sourceos-spec`.
