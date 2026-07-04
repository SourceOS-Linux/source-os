# AgentPlane integration placement

`source-os` is the Linux realization home for the SourceOS control-plane stack.

## What belongs here

This repository should carry the concrete Linux and Nix realization for:

- host roles and host profiles
- image definitions
- builder definitions
- machine-level deployment targets
- integration points that realize the `agentplane` control-plane contract on Linux hosts

## What does not belong here

This repository is not the canonical home for the shared control-plane schema or policy canon.

Those shared definitions belong in `SocioProphet/socioprophet-agent-standards`.

The control-plane lifecycle, placement, promotion, reversal, and evidence topology belong in `SocioProphet/agentplane`.

## Repository relationship

- `SocioProphet/agentplane` defines the execution and promotion control-plane model.
- `SocioProphet/socioprophet-agent-standards` defines shared schemas and vocabulary.
- `SourceOS-Linux/source-os` realizes the Linux build, image, and host surfaces.

## Immediate implication

Future Nix/host/image work for SourceOS should be added here with explicit references back to the `agentplane` contract rather than re-defining control-plane semantics locally.
