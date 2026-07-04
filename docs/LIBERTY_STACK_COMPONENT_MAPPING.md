# Liberty Stack component mapping

## Purpose

This note maps the upstream Liberty Stack standards and the downstream `prophet-platform` runtime lane onto candidate Linux host/substrate components in `source-os`.

## Boundary

- `socioprophet-agent-standards` remains the canonical semantic source of truth
- `prophet-platform` remains the runtime/operator workflow surface
- `source-os` is the Linux packaging, host profile, and service-composition layer

## Candidate component mapping

### Identity and trust
- `authentik` — identity and auth surface
- `step-ca` — host and service trust issuance

### Reachability and overlay
- `headscale` — private coordination plane for node reachability

### Storage and access
- `garage` — object storage substrate
- `sftpgo` — multi-protocol access surface over storage

### Backup and restore
- `restic` — backup and restore execution surface

## First substrate responsibilities

The first `source-os` implementation tranche should make it possible to:
1. declare the component set for one Liberty Stack host profile
2. place service units or container definitions for the first component group
3. attach validation notes for bootstrap and local bring-up

## Deliberate limit

This note is still a mapping surface. It does not yet freeze package managers, service managers, or deployment topology.
