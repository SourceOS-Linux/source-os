# sourceos-shell launcher bridge note

During the early shell rollout, launcher integration is tracked as temporary bridge work.

## Routing rule

Queries are routed by scope:

- `apps` -> launcher or desktop-entry provider
- `files` -> Linux-native file search only
- `web` -> browser or web agent

## Required invariant

For `files` queries, Albert must not perform a second file-search pass in parallel with the Linux-native provider.

## Realization scaffolds

The Linux realization currently carries placeholder search-provider material at:

- `linux/desktop/sourceos-search-provider.conf`
- `/etc/sourceos-shell/search-provider.json` (realized by the shell Nix module scaffold)

These capture the intended rollout mode and the provider choice for the Linux-native file search lane.

## Lifecycle

This bridge exists only until the shell's own command/search surface fully absorbs the routing behavior.
