# Workstation v0 Runbook (linux-dev)

This runbook is the operational guide for the **SourceOS Workstation Profile v0** Mac-on-Linux lane.

Target profile:

- `profiles/linux-dev/workstation-v0/`

Key properties:

- CLI-first, keyboard-first.
- GNOME customization is behavioral: GSettings, extensions, helper scripts, and packaged GNOME components.
- `sourceos` is installed as a profile-pinned wrapper.
- The launcher palette is open-source and Wayland-first.
- Mac-on-Linux behavior is bounded GNOME polish, not a full macOS clone.

---

## 0) Preconditions

Expected host:

- Fedora / Silverblue / CoreOS-derived host, or another Linux host with `dnf` or `rpm-ostree`.
- GNOME session for desktop integration.
- Homebrew/Linuxbrew available for the user-layer CLI toolset.

Quick checks:

```bash
uname -a && echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}" && command -v rpm-ostree || true && command -v dnf || true && command -v brew || true
```

If Homebrew/Linuxbrew is missing, install it first before expecting the full user-layer toolset to apply.

---

## 1) Apply the profile

From the repository root:

```bash
./profiles/linux-dev/workstation-v0/install.sh
```

What the installer applies:

- System package layer: `git`, `openssh-clients`, `podman`, `toolbox`, clipboard tools, `jq`, `sushi`, and `gnome-screenshot`.
- User CLI layer via the manifest-driven brew list.
- Shell spine files under `$XDG_CONFIG_HOME/sourceos/shell/`.
- `sourceos` wrapper under `~/.local/bin/sourceos`.
- `mac-screenshot.sh` wrapper under `~/.local/bin/mac-screenshot.sh`.
- Lampstand install lane, best effort.
- GNOME baseline, extension pinset, bounded appearance defaults, sidebar bookmarks, input/remap lane, Fusuma gesture lane, launcher install, palette hotkey, and mac-like defaults.

### rpm-ostree reboot note

On rpm-ostree systems, newly layered packages may not be active until reboot.

After install, reboot when rpm-ostree reports a pending deployment:

```bash
rpm-ostree status
systemctl reboot
```

After reboot, log into GNOME again and rerun validation.

---

## 2) Optional shell/fish autopatch

To let the installer patch shell/fish config files:

```bash
SOURCEOS_AUTOPATCH_SHELL=1 ./profiles/linux-dev/workstation-v0/install.sh
```

Unified command surface:

```bash
sourceos fix all dry-run
sourceos fix all apply
sourceos fix all revert

sourceos fix shell dry-run
sourceos fix shell apply
sourceos fix shell revert

sourceos fix fish dry-run
sourceos fix fish apply
sourceos fix fish revert
```

Low-level helpers remain available:

```bash
./profiles/linux-dev/workstation-v0/bin/patch-all.sh dry-run
./profiles/linux-dev/workstation-v0/bin/patch-shell.sh dry-run
./profiles/linux-dev/workstation-v0/bin/patch-fish.sh dry-run
```

---

## 3) Ensure PATH includes user wrappers

Check:

```bash
command -v sourceos && command -v mac-screenshot.sh && printf '%s\n' "$PATH" | tr ':' '\n' | grep -F "$HOME/.local/bin"
```

If missing, add this to the relevant shell rc:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## 4) Launcher palette

SourceOS uses an open-source launcher palette for `Super+Space`.

Priority order:

1. `fuzzel` for Wayland-first usage.
2. `wofi` fallback.
3. `rofi` fallback.
4. terminal fallback: `fzf`.

Invoke directly:

```bash
sourceos palette
```

The palette exposes profile actions, validation reports, Lampstand search/runtime commands, and common TUI tools.

---

## 5) Mac-on-Linux validation commands

Run the general status and doctor surfaces:

```bash
sourceos status
sourceos status --json
sourceos doctor
sourceos doctor --json
```

Launcher-friendly reports:

```bash
sourceos status --open
sourceos doctor --open
```

Exit codes:

- `0` means OK.
- `2` means missing required components or a hard profile failure.

Warnings in `status` and `doctor` are not automatically hard failures. Warnings usually indicate optional polish, desktop integration, or runtime services that are not installed, enabled, or active yet.

---

## 6) Mac polish checks

Run the aggregate workstation polish helper:

```bash
./profiles/linux-dev/workstation-v0/bin/check-workstation-polish.sh
```

Run component helpers directly:

```bash
./profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh
./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
```

Expected output style is `key=value` so the results can feed CI, status, and doctor surfaces.

Screenshot helper checks:

```bash
mac-screenshot.sh screen
mac-screenshot.sh area
mac-screenshot.sh window
mac-screenshot.sh interactive
mac-screenshot.sh open-dir
```

Default screenshot directory:

```bash
ls -la "$HOME/Pictures/Screenshots"
```

Quick preview check:

```bash
command -v sushi
```

---

## 7) Keyboard/remap policy checks

Default policy:

- `input-remapper` is the primary Fedora/GNOME backend.
- `xremap` is an explicit compatibility lane.
- Kinto is an explicit X11/xkeysnail compatibility lane and is not auto-installed by the Wayland-first profile.

Validate policy:

```bash
./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
SOURCEOS_REMAP_BACKEND=xremap ./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
SOURCEOS_REMAP_BACKEND=invalid ./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
```

Generate the xremap compatibility template:

```bash
SOURCEOS_REMAP_BACKEND=xremap ./profiles/linux-dev/workstation-v0/gnome/input-install.sh
cat "${XDG_CONFIG_HOME:-$HOME/.config}/sourceos/input/xremap-macos-compat.yml"
```

---

## 8) Lampstand checks

Search:

```bash
sourceos search 'report OR invoice' --snippet
sourceos search --prompt --snippet --open
```

Runtime inspection:

```bash
sourceos search health --open
sourceos search stats --open
sourceos search index --root "$HOME"
```

User unit controls:

```bash
sourceos search service status --open
sourceos search service restart
sourceos search service enable
sourceos search service logs --open
```

Unit helper:

```bash
./profiles/linux-dev/workstation-v0/bin/check-lampstand-unit.sh
```

---

## 9) GNOME integration checks

Hotkeys applied by `gnome/mac-defaults.sh` include:

- `Super+Space` for SourceOS palette.
- `Super+E` for Files.
- `Super+Return` for Terminal.
- `Super+Shift+3` for full-screen screenshot.
- `Super+Shift+4` for area screenshot.
- `Super+Shift+5` for interactive screenshot UI.
- `Super+Shift+6` for screenshots folder.

Inspect GNOME bindings:

```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
```

Extensions:

```bash
gnome-extensions list | grep -E 'dash-to-dock|appindicator' || true
```

GNOME changes may require logout/login after package layering or extension installation.

---

## 10) Acceptance matrix

The current implemented, validation-backed, planned, and non-goal states are tracked in:

```bash
cat docs/workstation/mac-on-linux-acceptance.md
```

Use that matrix for review and handoff. Planned items are not counted as delivered until there is a GitHub PR, branch, commit, or merge with validation evidence.

---

## 11) Warnings vs hard failures

Treat warnings as triage items, not automatic blockers.

Typical warnings:

- GNOME not detected in a headless/CI environment.
- Optional desktop polish helpers unavailable.
- Lampstand user unit not active yet.
- GNOME extensions not visible until logout/login.
- Runtime package not active until rpm-ostree reboot.

Treat hard failures as blockers when:

- `sourceos status` exits `2` due to missing required CLI/runtime basics.
- `sourceos doctor --json` does not parse.
- Required wrappers are missing after install.
- A helper script has syntax errors.

---

## 12) Known gaps and non-goals

Known gaps:

- Full doctor integration for aggregate polish is tracked separately.
- Dock/extension validation helper is tracked separately.
- Shortcut map contract is tracked separately.
- `sourceos-spec` alignment is tracked separately.

Non-goals for workstation-v0:

- No full macOS clone claim.
- No GNOME Shell fork.
- No libadwaita replacement.
- No proprietary asset requirement.
- No production readiness claim from fixture or helper validation alone.

---

## References

- `docs/workstation/README.md`
- `docs/workstation/mac-on-linux-acceptance.md`
- `profiles/linux-dev/workstation-v0/`
- `profiles/linux-dev/workstation-v0/gnome/README.md`
