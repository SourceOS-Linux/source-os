# Model Plane on source-os (Tranche 7)

The Model Plane is source-os's tiered, on-device inference substrate: placement tiers
**T0–T4** where a tier boundary *is* a data-residency boundary, with provenance receipts,
consent-gated escalation, and governed distillation. The canonical contracts are owned by
`SourceOS-Linux/sourceos-spec` (Tranche 7); source-os is a downstream **emitter**.

## Status

This directory currently ships the **emitter shim** for the serving path — the smallest
real slice that proves source-os can emit a spec-conformant, hash-chained
`InferenceReceipt` natively. The full daemon set is not yet built.

| Slice | Item | State |
|-------|------|-------|
| T7-9  | `docs/model-plane/architecture.md` | this stub |
| T7-10 | `profiles/model-plane/{constrained,standard,workstation,cluster-node}.nix` | not built |
| T7-11 | `modules/modelplaned/` (catalog + residency) | not built |
| T7-12 | `modules/inferenced/` (serving) | **emitter shim only** (`modules/model-plane/inferenced_shim.py`) |
| T7-13 | `modules/embeddingd/` | not built |
| T7-14 | `modules/visiond/` (no network namespace) | not built |
| T7-15 | `modules/distilld/` (governed distillation) | not built |
| T7-20 | `docs/seam-registry.md` — SEAM-014..017 | not built |

Everything not built here is tracked in the T7 follow-up issue.

## Receipt spine (SEAM-011)

Every completion a serving daemon finishes must leave an `InferenceReceipt` in the estate's
single **hash-chained** ledger — a local-only ledger is not permitted (SEAM-011). source-os
**consumes** the canonical emitter (`prophet-platform apps/receipt-gateway`,
vendored byte-verbatim under `modules/model-plane/tools/`); it does not re-implement the
chain. `modules/model-plane/inferenced_shim.py` is the serving-path caller: given the
content-addressed base-model digest and the input/output of a finished completion, it
appends an on-device receipt via the vendored `emit_receipt()`.

Teeth (`.github/workflows/model-plane-receipts.yml`): a produced receipt validates against
`InferenceReceipt.schema.json` and chains (prevHash continuity); a tampered entry and a
local-only (unchained) entry are both rejected; and the vendored emitter is asserted to
match the canonical sha256 (consume-not-fork guard).

## Off-device escalation

An on-device (`on_device_only`) completion carries no lease and no escalation. A completion
served off-device (`sovereign_cluster` / `external_permitted`) crosses a data boundary and
must carry an authorizing capability lease and a non-empty escalation chain (SEAM-015);
the schema enforces this. Off-device serving is out of scope for the emitter shim.
