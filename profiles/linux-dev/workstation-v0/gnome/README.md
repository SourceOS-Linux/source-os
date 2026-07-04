# GNOME baseline (workstation-v0)

This directory contains a **minimal GNOME baseline** for the workstation profile.

Principles:

- Behavioral configuration via **GSettings**.
- Conservative defaults that are stable across GNOME upgrades.
- Avoid invasive keybinding rewrites until we pin and validate a full shortcut map.
- Mac-like behavior is implemented as bounded GNOME defaults, helper scripts, and packaged GNOME components.

## Apply

```bash
./apply.sh
./extensions-install.sh
./appearance-apply.sh
./files-sidebar.sh
./mac-defaults.sh
./input-install.sh
```

## Current baseline (v0)

- Enable window buttons: close/minimize/maximize (left)
- Touchpad: tap-to-click + natural scrolling
- Show battery percentage
- Show weekday/date in clock
- Enable dynamic workspaces
- Dash-to-Dock and AppIndicator extension pinset
- SourceOS palette on `Super+Space`
- Files on `Super+E`
- Terminal on `Super+Return`

## Mac polish v1

- Quick preview through Fedora's `sushi` package
- Screenshot helper wrapper installed as `~/.local/bin/mac-screenshot.sh`
- Screenshot output directory at `~/Pictures/Screenshots`
- `Super+Shift+3` full-screen screenshot
- `Super+Shift+4` area screenshot
- `Super+Shift+5` interactive screenshot UI
- `Super+Shift+6` open screenshot directory

## Mac defaults validation

The mac-like GNOME defaults script can be inspected without running GNOME:

```bash
./profiles/linux-dev/workstation-v0/bin/check-mac-defaults.sh
```

The helper emits key=value output for the expected behavior slice, including hot corners, 12h clock, locate pointer, Nautilus click policy, dock favorites, Files/Terminal bindings, screenshot bindings, and screenshot directory setup.

It is read-only and does not change active keybindings or GNOME settings.

## Appearance/sidebar polish v1

This lane adds bounded visual/workflow polish without replacing GNOME Shell or libadwaita:

- `appearance-apply.sh` applies stable GNOME interface settings such as color-scheme preference, cursor size, font antialiasing, overlay scrolling, and primary-selection paste behavior.
- `files-sidebar.sh` seeds GTK/Nautilus bookmarks for Desktop, Documents, Downloads, Pictures, Screenshots, Music, Videos, and Public.
- The workstation installer runs both helpers best-effort after the extension pinset and before input/gesture setup.

## Extension/dock validation helper

`check-gnome-extensions.sh` emits `key=value` status for the GNOME extension and dock lane so that `doctor`, `status`, and CI can reason about it without a live GNOME session.

Keys emitted:

| Key | Values |
|-----|--------|
| `gnome_detected` | `yes` / `no` |
| `gnome_extensions_cli` | `present` / `missing` |
| `gsettings` | `present` / `missing` |
| `dash_to_dock` | `enabled` / `present` / `missing` / `unknown` |
| `appindicator` | `enabled` / `present` / `missing` / `unknown` |
| `favorite_apps` | gsettings value or `unknown` |
| `dock_position` | gsettings value or `unknown` |
| `dock_autohide` | gsettings value or `unknown` |
| `dock_intellihide` | gsettings value or `unknown` |

**Known gaps:** extension status is `unknown` when `gnome-extensions` CLI is absent (e.g. on a CI runner or server).  Dock gsettings keys are `unknown` when the Dash-to-Dock schema is not installed.

```bash
bash -n gnome/check-gnome-extensions.sh   # syntax check
bash    gnome/check-gnome-extensions.sh   # emit status
```

## Keyboard/remap policy v1

The workstation keeps keyboard remapping explicit and policy-gated:

- `input-remapper` remains the default Fedora/GNOME backend because it is packaged and works at the evdev layer.
- `xremap` is the advanced compatibility lane; the installer writes a template at `$XDG_CONFIG_HOME/sourceos/input/xremap-macos-compat.yml`.
- Kinto remains an explicit compatibility lane for X11/xkeysnail-style workflows and is not auto-installed in the Wayland-first profile.
- `check-keyboard-policy.sh` emits key=value status for CI and future doctor/status integration.

## Dock/extension validation

The dock and extension lane can be inspected without changing system state:

```bash
./profiles/linux-dev/workstation-v0/bin/check-gnome-dock-extension.sh
```

The helper emits key=value output for:

- `gnome_extensions`
- `gsettings`
- `dash_to_dock`
- `appindicator`
- `favorite_apps_visibility`
- `gnome_dock_extension_lane_ok`

It is read-only and does not install, enable, or modify extensions.

## Follow-on work

- Wayland-safe keyboard remap lane expansion
- Optional bounded icon/cursor/font package set
- More complete macOS-style shortcut map after validation
