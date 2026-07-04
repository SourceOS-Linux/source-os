# Liberty Stack Linux substrate

## Purpose

This document reserves and defines the first Linux-substrate realization surface for the Liberty Stack lane inside `source-os`.

The upstream semantic source of truth remains:
- `SocioProphet/socioprophet-agent-standards` for AgentOS, M2, and Liberty Stack standards
- `SocioProphet/prophet-platform` for runtime and operator-facing workflow consumption

This repository is the Linux host and packaging realization layer.

## Substrate responsibilities

The Linux substrate slice should eventually cover:
- host profile and package requirements
- service composition for local-first liberty stack components
- systemd or container service units
- configuration placement and secret reference wiring
- bootstrap and validation flows for Linux workstations and nodes

## First candidate components

The first substrate slice is expected to carry host-facing integration for components such as:
- headscale
- step-ca
- authentik
- garage
- sftpgo
- restic
- supporting validation and bootstrap helpers

## Deliberate limits

This note does not make `source-os` a second standards authority.

It exists to keep the Linux realization boundary explicit so packaging, service units, and host bootstrap logic do not drift back into the standards repo or the platform runtime repo.
