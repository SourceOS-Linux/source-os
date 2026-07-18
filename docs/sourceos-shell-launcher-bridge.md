# sourceos-shell command bus note

During the early shell rollout, launcher/search integration is tracked as temporary command-bus work.

## Routing rule

Queries are routed by scope:

- `apps` -> launcher or desktop-entry provider
- `files` -> Linux-native file search only
- `web` -> browser or web agent

## Required invariant

For `files` queries, the command bus must not perform a second file-search pass in parallel with the Linux-native provider.

Lampstand is the intended Linux-native file authority for this lane.

## Realization scaffolds

The Linux realization currently carries placeholder search-provider material at:

- `linux/desktop/sourceos-search-provider.conf`
- `/etc/sourceos-shell/search-provider.json` (realized by the shell Nix module scaffold)

These capture the intended rollout mode, routing invariant, and the provider choice for the Linux-native file search lane.

## Lifecycle

This command-bus/search-provider surface exists only until the shell's own command/search runtime fully absorbs the routing behavior.
