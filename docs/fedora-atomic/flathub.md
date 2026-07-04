# Flathub setup (Fedora Atomic)

Goal: add the Flathub remote in a way that is **auditable, idempotent, and user-scoped**.

## CLI (preferred)

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remotes --show-details
```

Verify:
- Remote name is `flathub`
- URL and/or collection points to `dl.flathub.org`

## GNOME Software (GUI)

If you use the browser workflow:
- download `flathub.flatpakrepo`
- open with **Software Install**
- confirm the **Source** shows `dl.flathub.org`
- click **Install**

## Notes on provenance

- Flathub hosts both FOSS and proprietary apps.
- SourceOS policy can require license-allowlisting per-app (separate policy surface).
- Flatpak itself has signature verification; we still treat permissions as part of the trust boundary.

## Useful commands

List apps and origins:

```bash
flatpak list --app --columns=application,origin,version
```

Update:

```bash
flatpak update
```
