# rpm-ostree package layering (Fedora Atomic)

Use rpm-ostree layering only when the component must live on the host (kernel-adjacent, drivers, system daemons, virtualization stacks).
Layering creates a **new deployment** (a new bootable root) and typically requires a reboot.

## Install a package

```bash
rpm-ostree install <package>
rpm-ostree status
systemctl reboot
```

## Remove a layered package

```bash
rpm-ostree uninstall <package>
rpm-ostree status
systemctl reboot
```

## Rollback

If the new deployment misbehaves:

```bash
rpm-ostree status
rpm-ostree rollback
systemctl reboot
```

## Replace/override (advanced)

`rpm-ostree override replace` exists for testing alternate builds of host packages.
This is an advanced workflow and should be tracked as a governed change.

## Operational posture

- Prefer: Flatpak (GUI) + Toolbox (CLI)
- Use layering sparingly
- Always record: what changed, why, and how to roll back
