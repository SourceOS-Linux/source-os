# Toolbox on Fedora Atomic

Toolbox provides a mutable Fedora user-container for CLI tools and development dependencies.
This keeps the host OS clean and rollback-friendly.

## Create profiles (examples)

### Dev toolbox

```bash
toolbox create --container dev || true
```

Enter:

```bash
toolbox enter --container dev
```

Install tools inside the toolbox:

```bash
sudo dnf install -y git make gcc gcc-c++ python3 python3-pip ripgrep fd-find
```

## Policy notes

- Treat toolbox as a *controlled mutable lane*.
- Prefer per-project environments inside toolbox (venv/conda/pixi) rather than polluting the toolbox root.

## Useful commands

List toolboxes:

```bash
toolbox list
```

Remove a toolbox:

```bash
toolbox rm --container dev
```
