# linux-dev / workstation-v0

This directory realizes the **Workstation Profile v0** for the `linux-dev` channel.

It is a *host/profile realization surface* (per `docs/repository-layout.md`) rather than the canonical design/RFC.

Design/RFC source of truth:
- `SociOS-Linux/enhancements` → SourceOS Workstation Profile v0

Typed contract boundary:
- `SourceOS-Linux/sourceos-spec` (ADR 0001)

## What this profile provides

- A modern CLI-first tool bundle
- A shell UX spine (fzf/atuin/zoxide/direnv + clipboard helpers)
- Optional toolbox/AUR bridge for immutable hosts
- A local `sourceos` helper CLI

## Apply

```bash
./install.sh
```

## Verify

```bash
./doctor.sh
```
