# Flatpak permissions + sandbox audit

Flatpak is a strong default lane, but its security properties depend on:
- the sandbox permissions granted to each app
- portal usage vs direct filesystem access

## Inspect permissions

Install Flatseal (GUI permission inspector):

```bash
flatpak install flathub com.github.tchx84.Flatseal
```

From CLI, basic info:

```bash
flatpak info --show-permissions <app-id>
```

## Common risk patterns

- `--filesystem=host` or broad `home` access for apps that do not need it
- `--talk-name=org.freedesktop.secrets` or other broad DBus access without justification
- excessive device access (e.g., camera/mic) without necessity

## Recommended posture

- Start permissive only when required; then tighten.
- Prefer portal-based workflows (file chooser portal) vs raw filesystem mounts.
- Treat permission broadening as a governed change (like capability escalation).
