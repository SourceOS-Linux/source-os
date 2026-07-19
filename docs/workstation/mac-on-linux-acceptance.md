# Mac-on-Linux Acceptance Matrix

This matrix records the current SourceOS workstation-v0 Mac-on-Linux scope. It is an acceptance aid for reviewers and agents, not a claim of full macOS parity.

Status values:

- `implemented`: concrete helper/config/package surface exists.
- `validation-backed`: concrete surface exists and has a helper, workflow, or smoke validation path.
- `planned`: desired future behavior, not active yet.
- `non-goal`: intentionally out of scope for workstation-v0.

| Feature | Status | Current evidence | Notes |
|---|---|---|---|
| SourceOS palette on `Super+Space` | implemented | `profiles/linux-dev/workstation-v0/gnome/palette-hotkey.sh`; `profiles/linux-dev/workstation-v0/bin/sourceos` | Launcher remains an action bus, not a duplicate file index. |
| Files shortcut on `Super+E` | implemented | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh` | Opens Nautilus. |
| Terminal shortcut on `Super+Return` | implemented | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh` | Uses GNOME Terminal. |
| Screenshot full screen / area / UI / folder bindings | validation-backed | `profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh`; `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`; `.github/workflows/workstation-mac-polish.yml` | Uses `Super+Shift+3`, `Super+Shift+4`, `Super+Shift+5`, `Super+Shift+6`. |
| Quick Look-style preview | implemented | `profiles/linux-dev/workstation-v0/manifest.yaml`; `profiles/linux-dev/workstation-v0/install.sh` | Uses Fedora/GNOME `sushi`; no custom previewer. |
| Finder-like sidebar bookmarks | validation-backed | `profiles/linux-dev/workstation-v0/gnome/files-sidebar.sh`; `.github/workflows/workstation-mac-polish.yml` | Seeds GTK/Nautilus bookmarks for standard folders. |
| Bounded appearance defaults | implemented | `profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh` | Uses stable GNOME settings; does not replace GNOME Shell or libadwaita. |
| `input-remapper` primary keyboard backend | validation-backed | `profiles/linux-dev/workstation-v0/gnome/input-install.sh`; `profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh`; `.github/workflows/workstation-keyboard-policy.yml` | Default Fedora/GNOME lane. |
| `xremap` compatibility lane | validation-backed | `profiles/linux-dev/workstation-v0/gnome/input-install.sh`; `profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh` | Advanced compatibility template, not the default. |
| Kinto compatibility lane | planned | `profiles/linux-dev/workstation-v0/manifest.yaml`; `profiles/linux-dev/workstation-v0/gnome/README.md` | Explicit compatibility path for X11/xkeysnail workflows; not auto-installed by the Wayland-first profile. |
| Touchpad gestures / Fusuma | implemented | `profiles/linux-dev/workstation-v0/gnome/fusuma-install.sh`; `profiles/linux-dev/workstation-v0/gnome/fusuma-apply.sh` | Gesture lane exists; deeper gesture parity remains future work. |
| Lampstand-backed local file search | validation-backed | `profiles/linux-dev/workstation-v0/bin/sourceos-search.sh`; `profiles/linux-dev/workstation-v0/bin/install-lampstand.sh`; `.github/workflows/workstation-lampstand.yml` | Lampstand is the file authority; launcher remains action bus. |
| Aggregate polish validation | validation-backed | `profiles/linux-dev/workstation-v0/bin/check-workstation-polish.sh`; `.github/workflows/workstation-polish-validation.yml` | Aggregates Mac polish and keyboard policy signals. |
| Status warnings for aggregate polish | validation-backed | `profiles/linux-dev/workstation-v0/bin/sourceos`; `.github/workflows/workstation-status-polish.yml` | Adds warnings without changing status JSON shape. |
| Doctor integration for aggregate polish | planned | `SourceOS-Linux/source-os#120` | Issue-first work packet exists; not counted delivered until GitHub artifact exists. |
| Dock / extension validation helper | planned | `SourceOS-Linux/source-os#130` | Issue-first work packet exists; no verified GitHub artifact yet. |
| Shortcut map contract | planned | `SourceOS-Linux/source-os#126` | Issue-first work packet exists; no verified GitHub artifact yet. |
| Operator runbook | planned | `SourceOS-Linux/source-os#132` | Issue-first work packet exists; no verified GitHub artifact yet. |
| Full macOS UI clone | non-goal | This document | Workstation-v0 targets bounded GNOME behavior, not shell replacement or proprietary asset cloning. |
| Proprietary dependency requirement | non-goal | This document | Open, self-hostable, auditable components are preferred. |

## Acceptance posture

For workstation-v0, a feature is considered usable when it has both a concrete realization surface and validation evidence. Documentation-only planned items are useful backlog, but not counted as delivered.

## Validation

```bash
test -s docs/workstation/mac-on-linux-acceptance.md
grep -F "implemented" docs/workstation/mac-on-linux-acceptance.md
grep -F "validation-backed" docs/workstation/mac-on-linux-acceptance.md
grep -F "non-goal" docs/workstation/mac-on-linux-acceptance.md
```
