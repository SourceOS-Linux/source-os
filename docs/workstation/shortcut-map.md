# Workstation v0 Shortcut Map Contract

This contract records the current workstation-v0 Mac-on-Linux shortcut surface and separates active bindings from proposed future bindings.

It is documentation and validation guidance only. It does not change active keybindings.

## Active bindings

| Action | Binding | Enforced by | Status |
|---|---|---|---|
| SourceOS palette | `Super+Space` | `profiles/linux-dev/workstation-v0/gnome/palette-hotkey.sh` | active |
| Files / Nautilus | `Super+E` | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh` | active |
| Terminal | `Super+Return` | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh` | active |
| Full-screen screenshot | `Super+Shift+3` | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`; `profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh` | active |
| Area screenshot | `Super+Shift+4` | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`; `profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh` | active |
| Interactive screenshot UI | `Super+Shift+5` | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`; `profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh` | active |
| Screenshots folder | `Super+Shift+6` | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`; `profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh` | active |

## Active compatibility policy

| Lane | Status | Enforced by | Notes |
|---|---|---|---|
| `input-remapper` primary backend | active policy | `profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh`; `profiles/linux-dev/workstation-v0/gnome/input-install.sh` | Default Fedora/GNOME path. |
| `xremap` compatibility backend | active compatibility lane | `profiles/linux-dev/workstation-v0/gnome/input-install.sh` | Writes `$XDG_CONFIG_HOME/sourceos/input/xremap-macos-compat.yml` when explicitly selected. |
| Kinto compatibility | documented compatibility lane | `profiles/linux-dev/workstation-v0/manifest.yaml`; `profiles/linux-dev/workstation-v0/gnome/README.md` | X11/xkeysnail-style compatibility. Not auto-installed in the Wayland-first profile. |

## Proposed future bindings, not active

These are backlog candidates and must not be treated as implemented until a GitHub PR, branch, commit, or merge proves delivery with validation evidence.

| Proposed action | Candidate binding | Status | Notes |
|---|---|---|---|
| Spotlight-like global search refinement | `Super+Space` with richer provider routing | planned | Current palette exists; provider richness remains future work. |
| Mission-control style overview tuning | TBD | planned | Must remain GNOME/Wayland-safe. |
| App switching parity refinements | TBD | planned | Requires explicit remap policy and validation. |
| Text-editing macOS modifier parity | TBD | planned | Must be validated per backend; not safe to assume globally. |
| Full macOS shortcut parity | none | non-goal for v0 | v0 targets bounded GNOME polish, not a clone. |

## Validation commands

```bash
test -s docs/workstation/shortcut-map.md
grep -F "Super+Shift+3" docs/workstation/shortcut-map.md
grep -F "active" docs/workstation/shortcut-map.md
grep -F "planned" docs/workstation/shortcut-map.md
grep -F "non-goal" docs/workstation/shortcut-map.md
```

## Boundaries

- This document does not modify keybindings.
- Active binding changes belong in `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh` or `palette-hotkey.sh`.
- Backend remap changes belong in `profiles/linux-dev/workstation-v0/gnome/input-install.sh` and must be validated by `check-keyboard-policy.sh`.
- Future parity claims must remain planned until backed by GitHub-visible implementation and validation evidence.
