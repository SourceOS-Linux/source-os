# Fedora Atomic (Silverblue/Kinoite/Sway Atomic): software supply lanes

SourceOS treats Fedora Atomic desktops as an **immutable host** with three intentionally distinct software lanes.

1) **Flatpak (GUI apps)** — default, sandboxed, user-scoped. Prefer this for desktop apps.
2) **Toolbox (CLI + dev tools)** — mutable container for compilers, debuggers, CLIs, SDKs.
3) **rpm-ostree layering (host mutations)** — last resort for host-integrated components (drivers, libvirt, kernel-adjacent tools). Requires new deployment + reboot.

If we violate this split, we lose the main benefits of Atomic: transactional updates, clean rollback, and a predictable trust boundary between user-space and the host.

## Decision tree

- Need a GUI app? → **Flatpak**
- Need CLI/dev tooling? → **Toolbox**
- Must run as a host service / kernel-adjacent / driver / system daemon? → **rpm-ostree layering**

## Quick commands

### Add Flathub (idempotent)

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remotes --show-details | sed -n '1,200p'
```

### Install an app (example)

```bash
flatpak install flathub org.libreoffice.LibreOffice
flatpak install flathub com.github.tchx84.Flatseal
```

### Toolbox (create + enter)

```bash
toolbox create --container dev || true
toolbox enter --container dev
```

### Host layering (sparingly)

```bash
rpm-ostree install <package>
rpm-ostree status
systemctl reboot
```

## Docs

- [Flathub setup + verification](./flathub.md)
- [Toolbox profiles](./toolbox.md)
- [rpm-ostree layering + rollback](./rpm-ostree-layering.md)
- [Flatpak permissions + sandbox audit](./flatpak-permissions.md)
