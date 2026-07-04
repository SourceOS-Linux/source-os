# Workstation local control node and Node Commander (v0)

## Purpose

This note captures the current workstation-side design for using a developer/operator machine as the first local control node for SourceOS / SociOS Linux work.

It is intentionally narrow and is meant to sit alongside the active workstation-v0 branch stack.

## What this covers

The local control node is the operator-side machine that is responsible for:

- applying the workstation/bootstrap profile
- hosting the first local command/runtime helper (`Node Commander`)
- building or dispatching OCI-based helper workloads
- launching local validation flows before promotion
- collecting the first evidence needed to decide whether a build may advance

## Current proven shape

The current implementation path has already demonstrated the following operator-node envelope:

- declarative host configuration on macOS via nix-darwin
- Podman machine for local OCI execution
- OCI image build/push/run for a bootstrap `node-commander` image
- user-scoped launch-agent execution model for the local runtime
- local-first posture rather than cloud-first orchestration

This is enough to define the workstation/control-node seam even though the runtime itself is still a bootstrap placeholder.

## Local-first rule

The workstation control node should follow a hard ordering:

1. local operator host
2. trusted private Linux builder or private executor
3. attested fog executor
4. burst cloud only when explicitly enabled

This note treats that ordering as a design rule, not a soft cost preference.

## Relationship to the active workstation-v0 stack

This note is intended to complement the current stacked workstation PR chain:

- profile scaffold / CLI / install / doctor
- shell spine
- shell-spine installer wiring

Those PRs establish the operator host as a usable workstation. This note captures the next seam: using that workstation as the local control node for OCI-backed `Node Commander` and pre-promotion validation work.

## Immediate workstation-side responsibilities

At the workstation/bootstrap layer, this repo should own:

- operator-host bootstrap and profile application
- shell/tooling ergonomics for control-node use
- local Podman/OCI runtime setup where appropriate for the host lane
- local directories and host-side bootstrap paths used by `Node Commander`

This repo should not become the canonical contract home for the typed SourceOS control-node semantics. Those belong upstream in `SourceOS-Linux/sourceos-spec`.

## Expected downstream bindings

This workstation/control-node lane is expected to bind downstream into:

- `SourceOS-Linux/sourceos-spec`
  - typed contracts / ADRs for control-node and image-promotion concepts
- `SocioProphet/agentplane`
  - execution, placement, replay, and evidence consumption
- `SocioProphet/prophet-platform`
  - deployable runtime/service implementation once the real `Node Commander` implementation is ready

## Near-term follow-on work

1. replace the bootstrap placeholder `Node Commander` image with the real runtime
2. mount explicit config/state paths into the local runtime envelope
3. bind local validation outputs into the promotion/evidence path
4. connect the workstation lane to the eventual Linux builder and image-validation flow

## Non-goals in this note

This note does not define the final typed schemas.
It does not redefine execution/evidence ownership away from `agentplane`.
It does not make cloud execution the default path.
