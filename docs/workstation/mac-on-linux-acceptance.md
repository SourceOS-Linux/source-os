# Mac-on-Linux Acceptance Matrix (workstation-v0)

This matrix tracks the status of every Mac-on-Linux feature in the
`linux-dev/workstation-v0` profile lane.

## Status key

| Status | Meaning |
|---|---|
| **implemented** | Code exists, ships in the installer, and is exercised on every apply. |
| **validation-backed** | Implemented and additionally verified by a doctor/CI check or contract test. |
| **planned** | Scoped and known; not yet implemented. |
| **non-goal** | Explicitly out-of-scope for this lane. |

---

## Feature matrix

### Launcher / palette

| Feature | Status | Helper / script path |
|---|---|---|
| `Super+Space` → SourceOS palette (`sourceos palette`) | **validation-backed** | [`profiles/linux-dev/workstation-v0/gnome/palette-hotkey.sh`](../../profiles/linux-dev/workstation-v0/gnome/palette-hotkey.sh) |
| Palette backed by fuzzel (primary) with wofi/rofi fallback | **implemented** | [`profiles/linux-dev/workstation-v0/bin/sourceos`](../../profiles/linux-dev/workstation-v0/bin/sourceos) |
| Lampstand search surfaced via palette as action bus | **implemented** | [`profiles/linux-dev/workstation-v0/bin/sourceos-search.sh`](../../profiles/linux-dev/workstation-v0/bin/sourceos-search.sh) |

### Files / Finder shortcut

| Feature | Status | Helper / script path |
|---|---|---|
| `Super+E` → Nautilus (`nautilus --new-window`) | **validation-backed** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — custom1 binding |
| Doctor verifies Files keybinding slot (custom1) | **validation-backed** | [`profiles/linux-dev/workstation-v0/doctor.sh`](../../profiles/linux-dev/workstation-v0/doctor.sh) — `check_mac_defaults` |

### Terminal shortcut

| Feature | Status | Helper / script path |
|---|---|---|
| `Super+Return` → `gnome-terminal` | **validation-backed** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — custom2 binding |
| Doctor verifies Terminal keybinding slot (custom2) | **validation-backed** | [`profiles/linux-dev/workstation-v0/doctor.sh`](../../profiles/linux-dev/workstation-v0/doctor.sh) — `check_mac_defaults` |

### Screenshots

| Feature | Status | Helper / script path |
|---|---|---|
| `Super+Shift+3` full-screen screenshot | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — custom3 binding |
| `Super+Shift+4` area screenshot | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — custom4 binding |
| `Super+Shift+5` interactive screenshot UI | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — custom5 binding |
| `Super+Shift+6` open screenshots folder | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — custom6 binding |
| `mac-screenshot.sh` wrapper installed to `~/.local/bin` | **implemented** | [`profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh`](../../profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh) |
| `~/Pictures/Screenshots` output directory created on apply | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) |
| `check-mac-polish.sh` validates screenshot helper and keybinding slots | **validation-backed** | [`profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh`](../../profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh) |

### Quick Look / Sushi

| Feature | Status | Helper / script path |
|---|---|---|
| Sushi package installed (Fedora: `sushi`) for Quick Look-style preview in Nautilus | **implemented** | [`profiles/linux-dev/workstation-v0/install.sh`](../../profiles/linux-dev/workstation-v0/install.sh) |
| `check-mac-polish.sh` checks `sushi` binary presence | **validation-backed** | [`profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh`](../../profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh) |
| Spacebar-triggered preview (requires upstream GNOME Files integration) | **non-goal** | Spacebar-to-preview is not remappable via GSettings alone without a Nautilus extension. |

### Sidebar bookmarks

| Feature | Status | Helper / script path |
|---|---|---|
| GTK/Nautilus bookmarks seeded (Desktop, Documents, Downloads, Pictures, Screenshots, Music, Videos, Public) | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/files-sidebar.sh`](../../profiles/linux-dev/workstation-v0/gnome/files-sidebar.sh) |
| Installer runs `files-sidebar.sh` best-effort | **implemented** | [`profiles/linux-dev/workstation-v0/install.sh`](../../profiles/linux-dev/workstation-v0/install.sh) — `apply_files_sidebar` |

### Appearance defaults

| Feature | Status | Helper / script path |
|---|---|---|
| Color-scheme preference (`default`/`prefer-dark`/`prefer-light`) | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh`](../../profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh) |
| Cursor size (24 px), text scaling (1.0), font antialiasing/hinting | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh`](../../profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh) |
| Overlay scrolling enabled | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh`](../../profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh) |
| Primary-selection paste disabled (closer to macOS clipboard model) | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh`](../../profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh) |
| Window controls left (close/minimize/maximize) | **validation-backed** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — `button-layout`; validated by `doctor.sh` |
| Hot corners off | **validation-backed** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — `enable-hot-corners false`; validated by `doctor.sh` |
| 12-hour clock | **validation-backed** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — `clock-format '12h'`; validated by `doctor.sh` |
| Dock favorites seeded (Nautilus, Terminal, Firefox, Settings) | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh`](../../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh) — `favorite-apps` |
| Proprietary fonts, themes, or icon packs | **non-goal** | Out-of-scope; bounded to stable GNOME interface settings only. |

### Keyboard / remap policy

| Feature | Status | Helper / script path |
|---|---|---|
| `input-remapper` as primary Fedora/Wayland/GNOME remap backend | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/input-install.sh`](../../profiles/linux-dev/workstation-v0/gnome/input-install.sh) |
| `xremap` compatibility template written to `$XDG_CONFIG_HOME/sourceos/input/xremap-macos-compat.yml` | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/input-install.sh`](../../profiles/linux-dev/workstation-v0/gnome/input-install.sh) — `write_xremap_template` |
| `check-keyboard-policy.sh` emits key=value status for CI and doctor | **validation-backed** | [`profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh`](../../profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh) |

#### xremap compatibility

| Feature | Status | Helper / script path |
|---|---|---|
| xremap template ships (CapsLock→Esc, modifier swap) | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/input-install.sh`](../../profiles/linux-dev/workstation-v0/gnome/input-install.sh) |
| xremap binary auto-installed | **non-goal** | Not auto-installed; template is written; user opts in explicitly. |

#### Kinto compatibility

| Feature | Status | Helper / script path |
|---|---|---|
| Kinto treated as explicit compatibility lane; not auto-installed | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/input-install.sh`](../../profiles/linux-dev/workstation-v0/gnome/input-install.sh) — documented and guarded |
| Kinto auto-install in Wayland-first profile | **non-goal** | Kinto depends on xkeysnail/X11; excluded from default Wayland-first path. |

### Gestures / Fusuma

| Feature | Status | Helper / script path |
|---|---|---|
| Fusuma config written to `~/.config/fusuma/config.yml` if absent | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/fusuma-apply.sh`](../../profiles/linux-dev/workstation-v0/gnome/fusuma-apply.sh) |
| Fusuma user systemd service installed when systemd available | **implemented** | [`profiles/linux-dev/workstation-v0/gnome/fusuma-install.sh`](../../profiles/linux-dev/workstation-v0/gnome/fusuma-install.sh) |
| Installer runs Fusuma lane best-effort | **implemented** | [`profiles/linux-dev/workstation-v0/install.sh`](../../profiles/linux-dev/workstation-v0/install.sh) — `apply_fusuma_install` |
| libinput-based gesture validation in CI | **planned** | No headless libinput smoke yet; planned for a future validation lane. |

### Lampstand search

| Feature | Status | Helper / script path |
|---|---|---|
| `sourceos search <query>` local file search surface | **implemented** | [`profiles/linux-dev/workstation-v0/bin/sourceos-search.sh`](../../profiles/linux-dev/workstation-v0/bin/sourceos-search.sh) |
| `bin/install-lampstand.sh` provisions Lampstand via pipx, prefers local checkout | **implemented** | [`profiles/linux-dev/workstation-v0/bin/install-lampstand.sh`](../../profiles/linux-dev/workstation-v0/bin/install-lampstand.sh) |
| Lampstand user unit (`sourceos-lampstand.service`) written when `lampstandd` available | **implemented** | [`profiles/linux-dev/workstation-v0/bin/install-lampstand.sh`](../../profiles/linux-dev/workstation-v0/bin/install-lampstand.sh) |
| `check-lampstand-unit.sh` validates unit status | **validation-backed** | [`profiles/linux-dev/workstation-v0/bin/check-lampstand-unit.sh`](../../profiles/linux-dev/workstation-v0/bin/check-lampstand-unit.sh) |
| Launcher treats Lampstand as file-search authority; no redundant second pass | **implemented** | [`docs/workstation/README.md`](README.md) — trust boundaries |

### Doctor / status validation

| Feature | Status | Helper / script path |
|---|---|---|
| `doctor.sh` validates mac-defaults GSettings (button-layout, hot-corners, clock-format, Files/Terminal bindings) | **validation-backed** | [`profiles/linux-dev/workstation-v0/doctor.sh`](../../profiles/linux-dev/workstation-v0/doctor.sh) — `check_mac_defaults` |
| `sourceos status --json` emits structured JSON status | **validation-backed** | [`profiles/linux-dev/workstation-v0/bin/sourceos`](../../profiles/linux-dev/workstation-v0/bin/sourceos) |
| `check-workstation-polish.sh` aggregates mac-polish + keyboard-policy checks | **validation-backed** | [`profiles/linux-dev/workstation-v0/bin/check-workstation-polish.sh`](../../profiles/linux-dev/workstation-v0/bin/check-workstation-polish.sh) |
| Contract test verifies mac-defaults shell correctness | **validation-backed** | [`tests/workstation-mac-defaults-contract.nix`](../../tests/workstation-mac-defaults-contract.nix) |
| `sourceos doctor --open` / `sourceos status --open` surface in launcher | **implemented** | [`profiles/linux-dev/workstation-v0/bin/sourceos`](../../profiles/linux-dev/workstation-v0/bin/sourceos) |
| Full macOS parity | **non-goal** | This lane targets Mac-like ergonomics on GNOME/Linux, not a macOS clone. |

---

## Validation commands

```bash
# Document exists and is non-empty
test -s docs/workstation/mac-on-linux-acceptance.md

# Status tokens present
grep -F "implemented" docs/workstation/mac-on-linux-acceptance.md
grep -F "non-goal" docs/workstation/mac-on-linux-acceptance.md
grep -F "validation-backed" docs/workstation/mac-on-linux-acceptance.md
grep -F "planned" docs/workstation/mac-on-linux-acceptance.md
```

Runtime checks (requires a provisioned workstation):

```bash
# Doctor: mac defaults + keybindings
./profiles/linux-dev/workstation-v0/doctor.sh

# Structured JSON status
sourceos status --json

# Polish check (mac + keyboard policy)
./profiles/linux-dev/workstation-v0/bin/check-workstation-polish.sh

# Screenshot helper presence
./profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh

# Keyboard policy
./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
```
