# Vendored: InferenceReceipt emitter

`inference_receipt_emitter.py` in this directory is **vendored byte-verbatim** (do not
edit) from the canonical emitter:

- Source: `SocioProphet/prophet-platform` — `apps/receipt-gateway/tools/inference_receipt_emitter.py`
- Pinned commit: `abd98805`
- Source sha256: `6881246b8e41a515fb1b29df645faeb9be17d8195d22a7e0d5ce15f8477d8e6a`
- Canonical owner of the schema: `SourceOS-Linux/sourceos-spec` (Tranche 7 / Model Plane)

`schemas/model-plane/InferenceReceipt.schema.json` is likewise vendored verbatim (its
`$comment` records the same provenance).

**Consume-not-fork (SEAM-011):** the hash-chain, canonical-JSON, and ledger logic are
consumed unchanged so this repo's receipts share one estate spine with the
receipt-gateway. Refresh by re-copying from prophet-platform; do not diverge. The only
source-os-specific code is `inferenced_shim.py`, which calls `emit_receipt()` — it does
not re-implement any chaining.

Refresh command:

```sh
cp <prophet-platform>/apps/receipt-gateway/tools/inference_receipt_emitter.py \
   modules/model-plane/tools/inference_receipt_emitter.py
cp <prophet-platform>/apps/receipt-gateway/schemas/model-plane/InferenceReceipt.schema.json \
   modules/model-plane/schemas/model-plane/InferenceReceipt.schema.json  # then re-add $comment
```
