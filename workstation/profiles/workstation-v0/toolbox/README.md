# Toolbox / AUR bridge

Workstation Profile v0 includes an optional **AUR bridge** for immutable hosts.

Rationale:

- On rpm-ostree/Silverblue/CoreOS derivatives, the host should remain minimal.
- AUR packages are often untrusted/fast-moving and should not collapse into SYSTEM trust.
- Toolbox provides an isolated user-space container that still has good UX (access to home, etc.).

This directory provides `sourceos-aur`, a small helper that:

- Creates an Arch Linux toolbox container
- Installs `base-devel` + `yay`
- Installs requested AUR packages inside the container

## Usage

```bash
workstation/profiles/workstation-v0/toolbox/sourceos-aur init
workstation/profiles/workstation-v0/toolbox/sourceos-aur install <aur-package>
```

## Notes

- Installed binaries live inside the container.
- Host integration should wrap execution via:

```bash
toolbox run --container sourceos-arch -- <cmd>
```

This is a deliberate boundary: it keeps AUR out of the host by default.
