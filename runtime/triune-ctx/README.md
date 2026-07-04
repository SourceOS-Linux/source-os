# triune-ctx

Triune runtime context primitives.

## Purpose

This module provides the typed runtime context that threads through the Triune planes:

- `Live`
- `Audit`
- `Replay`

It also provides a minimal attestation bundle binding:

- AUM identity
- kernel hash
- policy digest

## Current state

The current scaffold provides:

- plane enum
- typed context structure
- minimal stamp / verify helpers
- unit test proving a stamped context verifies

## Planned next steps

1. bind to a real attestation source rather than static stub values
2. attach context to watchdog / quorum / anchor flows
3. align directly with the `ReplayEnvelope` and `ValidatorDecision` contract surfaces
