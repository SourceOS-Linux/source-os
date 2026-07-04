# Workstation v0 Runbook (linux-dev)

This runbook is the operational “how we actually use it” guide for the **SourceOS Workstation Profile v0**.

Target profile:
- `profiles/linux-dev/workstation-v0/`

Key properties:
- CLI-first, keyboard-first.
- GNOME customization is **behavioral** (GSettings + extensions), no GNOME core forks.
- `sourceos` is installed as a **profile-pinned wrapper** (stable command surface).
- SourceOS uses an **open-source launcher palette** (Wayland-first) for Super+Space.

---

## 0) Preconditions

We assume:
- Fedora / Silverblue / CoreOS-derived host, or any Linux host with `dnf` or `rpm-ostree`.
- GNOME session if you want the GNOME integration.

Quick checks:

```bash
uname -a && echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}" && command -v rpm-ostree || true && command -v dnf || true
```

If Homebrew/Linuxbrew is not installed, install it first.

---

## 1) Apply the profile (repo-local)

From the repo root:

```bash
./profiles/linux-dev/workstation-v0/install.sh
```

The install sequence runs these steps in order:

1. **SYSTEM packages** (`install_system`) — installs via `rpm-ostree` or `dnf`:
   `git openssh-clients podman toolbox wl-clipboard jq xclip sushi gnome-screenshot`
2. **USER packages** (`install_user`) — installs via `brew` (manifest-driven)
3. **Shell spine** (`install_shell_spine`) — writes `$XDG_CONFIG_HOME/sourceos/shell/common.{sh,fish}`
4. **sourceos CLI** (`install_sourceos_cli`) — links helper to `~/.local/bin/sourceos`
5. **Lampstand backend** (`install_lampstand_backend`) — best-effort, non-fatal
6. **Shell autopatch** (`patch_shell_rc_if_enabled`) — only if `SOURCEOS_AUTOPATCH_SHELL=1`
7. **GNOME baseline** (`apply_gnome_baseline`)
8. **GNOME extensions** (`apply_gnome_extensions`)
9. **GNOME appearance defaults** (`apply_gnome_appearance`)
10. **Files sidebar defaults** (`apply_files_sidebar`)
11. **Input/remap lane** (`apply_input_install`)
12. **Fusuma gesture lane** (`apply_fusuma_install` + `apply_fusuma_config`)
13. **Launcher** (`apply_launcher_install`)
14. **Palette hotkey** (`apply_palette_hotkey`)
15. **Mac-like GNOME defaults pack** (`apply_mac_defaults`)

### rpm-ostree reboot notes

On Silverblue / CoreOS and any `rpm-ostree`-based host, SYSTEM packages are
**layered asynchronously**. The install script prints:

```
INFO: If new packages were layered, reboot before continuing.
```

**Required reboot sequence:**

```bash
# Step 1 — layer system packages (may succeed silently if already present)
./profiles/linux-dev/workstation-v0/install.sh

# Step 2 — reboot if new layers were applied
rpm-ostree status          # check pending deployment
sudo systemctl reboot      # reboot into the new deployment

# Step 3 — after reboot, re-run to complete user-space steps
./profiles/linux-dev/workstation-v0/install.sh
```

Steps 2–15 (user-space) are idempotent and safe to re-run.

### Optional: autopatch shell/fish config

If you want the installer to also patch your shell config files, run:

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

`fix all` orchestrates:
- bash/zsh rc patch helper
- fish config patch helper

Low-level helpers remain available too:

```bash
./profiles/linux-dev/workstation-v0/bin/patch-all.sh dry-run
./profiles/linux-dev/workstation-v0/bin/patch-all.sh apply
./profiles/linux-dev/workstation-v0/bin/patch-all.sh revert

./profiles/linux-dev/workstation-v0/bin/patch-shell.sh dry-run
./profiles/linux-dev/workstation-v0/bin/patch-shell.sh apply
./profiles/linux-dev/workstation-v0/bin/patch-shell.sh revert

./profiles/linux-dev/workstation-v0/bin/patch-fish.sh dry-run
./profiles/linux-dev/workstation-v0/bin/patch-fish.sh apply
./profiles/linux-dev/workstation-v0/bin/patch-fish.sh revert
```

---

## 2) Launcher palette (open-source)

SourceOS uses an open-source launcher palette for Super+Space.

Priority order:
1) `fuzzel` (Wayland-first, MIT)
2) `wofi` (GPL-3.0-only)
3) `rofi` (GPL)
4) terminal fallback: `fzf`

The palette is invoked by:

```bash
sourceos palette
```

The palette includes:
- fix all configs (dry-run/apply/revert)
- fix shell rc (dry-run/apply/revert)
- fix fish config (dry-run/apply/revert)
- status / doctor
- profile apply
- common TUI tools

---

## 3) Ensure PATH includes ~/.local/bin

`sourceos` is installed to `~/.local/bin/sourceos`.

Check:

```bash
command -v sourceos && echo "$PATH" | tr ':' '\n' | head
```

If missing:
- Add `export PATH="$HOME/.local/bin:$PATH"` to your shell rc.

---

## 4) Validate health

Terminal validation:

```bash
sourceos status
sourceos status --json
sourceos doctor
```

Launcher-friendly reports:

```bash
sourceos status --open
sourceos doctor --open
```

Exit codes:
- `0` = OK
- `2` = FAIL (missing required components)

### Warnings vs hard failures

The doctor surface uses three signal levels:

| Level   | Meaning                                              | Blocks install? |
|---------|------------------------------------------------------|-----------------|
| `ok`    | Component present and correctly configured.          | No              |
| `warn`  | Component missing or misconfigured but non-required. | No (soft gap)   |
| `error` | Required component absent; doctor exits `2`.         | Yes             |
| `info`  | Informational probe result (no verdict).             | No              |

**Hard failures (exit 2):** missing `git`, `ssh`, `podman`, `toolbox`, `wl-copy`,
`jq`, `brew`, `sourceos` binding, or `fzf`/`atuin`/`bat`/`zoxide`/`eza`/`yazi`/`gum`/
`direnv`/`rg`/`fd`/`tmux`/`lazygit`/`gh`/`tig`/`sesh`/`procs`/`sd`/`entr`/`curlie`/
`jnv`/`gojq`/`rclone`/`mc`/`rsync`.

**Warnings (non-blocking):** missing launcher (fuzzel/wofi/rofi), input-remapper/
xremap/xkeysnail, fusuma or fusuma config/service, xclip (X11 only), Lampstand
backend, or any GNOME mac-defaults gsettings mismatch.

Triage workflow:

```bash
# Quick pass — non-zero exit means hard failure
sourceos doctor; echo "exit: $?"

# Machine-readable view of all levels
sourceos doctor --json | python3 -m json.tool

# Count each level
sourceos doctor --json | python3 -c "
import json,sys
d=json.load(sys.stdin)
s=d['summary']
print(f\"ok={s['ok']} warn={s['warn']} error={s['error']} info={s['info']}\")
"
```

---

## 5) Mac polish helper

Validate the Mac-on-Linux polish surface (screenshot bindings, Sushi, `mac-screenshot.sh`
wrapper) with the dedicated check helper:

```bash
./profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh
```

Expected key=value output (all `present` is ideal; `missing` is non-fatal):

```
screenshot_helper=present       # mac-screenshot.sh in profile bin/
screenshot_wrapper=present      # mac-screenshot.sh reachable on PATH
gnome_screenshot=present        # gnome-screenshot package installed
sushi=present                   # sushi Quick Look previewer installed
screenshot_dir=present          # ~/Pictures/Screenshots directory exists
gsettings=present               # GNOME settings daemon reachable
custom3_slot=present            # Super+Shift+3 slot registered
custom4_slot=present            # Super+Shift+4 slot registered
custom5_slot=present            # Super+Shift+5 slot registered
custom6_slot=present            # Super+Shift+6 slot registered
```

Screenshot helper commands (copy/pasteable):

```bash
mac-screenshot.sh screen        # full-screen capture → ~/Pictures/Screenshots/
mac-screenshot.sh area          # interactive area capture
mac-screenshot.sh window        # window capture
mac-screenshot.sh interactive   # GNOME interactive screenshot UI
mac-screenshot.sh open-dir      # open ~/Pictures/Screenshots in Files
```

Quick Look preview: press `Space` on any file in Nautilus (requires `sushi` package).

---

## 6) Keyboard policy helper

Validate the keyboard remap policy (input-remapper primary, xremap/kinto compat):

```bash
./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
```

Expected key=value output:

```
default_backend=input-remapper
primary_backend=input-remapper
compatibility_backends=xremap,kinto
wayland_first=yes
kinto_auto_install=no
selected_backend=input-remapper
backend_valid=yes
selected_backend_available=present   # input-remapper binary reachable
input_remapper=present               # input-remapper-control on PATH
input_installer=present              # gnome/input-install.sh in profile
policy_ok=yes
```

Override the selected backend without changing host config:

```bash
SOURCEOS_REMAP_BACKEND=xremap ./profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh
```

`policy_ok=yes` is the acceptance signal; anything else indicates a policy
violation (unknown backend or selected backend not installed).

---

## 7) Lampstand checks

Validate the Lampstand search surface:

```bash
# Check binary / Python module availability and search-helper script
sourceos doctor --json | python3 -c "
import json,sys
for r in json.load(sys.stdin)['results']:
    if 'lampstand' in r['name']:
        print(r['level'].upper(), r['name'], '-', r['message'])
"

# Check user systemd unit (file / enabled / active)
./profiles/linux-dev/workstation-v0/bin/check-lampstand-unit.sh
```

Runtime search commands:

```bash
sourceos search 'report OR invoice' --snippet
sourceos search health --open
sourceos search stats --open
sourceos search index --root "$HOME"
```

Unit lifecycle commands:

```bash
sourceos search service status --open
sourceos search service restart
sourceos search service enable
sourceos search service logs --open
```

Lampstand failures are **warnings**, not hard failures. The search surface
degrades gracefully when the backend is absent.

---

## 8) GNOME integration

### Hotkey

The profile applies a GNOME custom keybinding:
- `<Super>space` → `sourceos palette`

If GNOME doesn’t pick it up immediately, log out/in.

### Extensions

The profile enables:
- dash-to-dock
- appindicator

On `rpm-ostree`, GNOME shell extensions may require reboot/logout after install.

---

## 9) One-line acceptance test

After install, this should succeed:

```bash
sourceos status --json && sourceos doctor
```

And on GNOME, you should be able to:
- press `<Super>space` to open the SourceOS palette
- run SourceOS actions from the palette

---

## 10) Known gaps and non-goals

### Known gaps (warnings, not blockers)

- **Lampstand backend** — installed best-effort via `pipx`; absent on fresh systems until
  `bin/install-lampstand.sh` completes successfully.  Doctor emits `warn`, not `error`.
- **fusuma** — gesture lane is best-effort; `fusuma` binary and user service are optional.
  User must be in the `input` group for fusuma to access devices.
- **GNOME extensions** — `dash-to-dock` and `appindicator` are installed best-effort.
  Extension activation may require a logout/reboot on immutable hosts.
- **xclip** — only needed on X11; absence on a pure Wayland session is expected.
- **mac-screenshot.sh PATH** — the wrapper is copied to `~/.local/bin` by
  `install-sourceos-cli.sh`; it only appears on PATH after a shell restart or
  `hash -r`.
- **GNOME mac-defaults gsettings** — mismatches emit `warn` (not `error`), meaning the
  mac-defaults pack may not yet have taken effect on the running session.

### Non-goals

- **Production readiness** — workstation-v0 is a developer-profile lane, not a
  hardened or production-certified configuration.
- **Non-GNOME desktops** — KDE, XFCE, and other desktops are out of scope.
  Mac polish and launcher sections are GNOME-specific.
- **Non-Fedora/Silverblue hosts** — the SYSTEM layer assumes `rpm-ostree` or `dnf`.
  Debian/Ubuntu and Arch hosts are not tested.
- **Modifying implementation scripts** — this runbook documents existing behavior;
  it does not alter `install.sh`, `doctor.sh`, or any helper script.
- **Kinto auto-install** — kinto is a supported compatibility lane but is not
  auto-installed; `kinto_auto_install=no` is the explicit policy.
- **CI workflow changes** — this runbook addition does not require workflow modifications.

---

## References

- `docs/workstation/README.md`
- `profiles/linux-dev/workstation-v0/`
- `profiles/linux-dev/workstation-v0/bin/check-mac-polish.sh`
- `profiles/linux-dev/workstation-v0/bin/check-keyboard-policy.sh`
- `profiles/linux-dev/workstation-v0/bin/check-lampstand-unit.sh`
