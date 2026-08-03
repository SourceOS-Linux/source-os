#!/usr/bin/env python3
"""`inferenced` receipt-emission shim (Model Plane, Tranche 7 — emitter half of T7-12).

The full `inferenced` serving daemon (T7-12) is not built here (it is blocker-laden:
HellGraph ledger service, base-model licensing, credentials). This shim is the SMALLEST
real slice that proves source-os can emit a spec-conformant, hash-chained
`InferenceReceipt` NATIVELY when a completion finishes: it takes the facts a real serving
daemon has at completion time (the content-addressed base-model digest, the task, and the
input/output) and appends an on-device receipt to the estate's hash-chained ledger
(SEAM-011: no local-only ledger).

Consume-not-fork: all chaining/canonicalisation/verification is delegated to the vendored
canonical emitter (tools/inference_receipt_emitter.py, byte-verbatim from
prophet-platform apps/receipt-gateway). This file adds no chain logic of its own.

CLI:
  inferenced_shim.py --ledger <path> --base-model-digest sha256:<64hex> \
                     --task <label> --input-file <f> --output-file <f>
  inferenced_shim.py --selftest    # emits + verifies a synthetic chain (labelled synthetic)

exit 0 ok; 1 conformance/chain failure; 2 usage/dependency error.
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "tools"))

try:
    import jsonschema
except ImportError:
    print("ERR: jsonschema not installed", file=sys.stderr)
    raise SystemExit(2)

from inference_receipt_emitter import (  # noqa: E402
    SCHEMA, canonical, emit_receipt, sha256, verify_ledger,
)


def _validator() -> "jsonschema.Draft202012Validator":
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(schema)
    return jsonschema.Draft202012Validator(schema)


def emit_completion_receipt(ledger: Path, *, base_model_digest: str, task: str,
                            input_text: str, output_text: str,
                            compute_device: str = "cpu") -> dict:
    """Emit one on-device InferenceReceipt for a finished completion (delegates to canonical)."""
    return emit_receipt(
        ledger, base_model_digest=base_model_digest, task=task,
        input_text=input_text, output_text=output_text,
        provider_daemon="inferenced", tier="T1", compute_device=compute_device,
    )


def _selftest() -> int:
    """Teeth: emit a synthetic chain, prove conformance + chaining, and prove the chain
    rejects a tampered entry and a local-only (unchained) entry. The completions are
    LABELLED SYNTHETIC — no model runs here; this proves the emitter path, not an LLM run."""
    validator = _validator()
    digest = "sha256:" + "a" * 64
    with tempfile.TemporaryDirectory() as d:
        ledger = Path(d) / "inference-ledger.jsonl"
        for i in range(3):
            r = emit_completion_receipt(
                ledger, base_model_digest=digest, task="selftest",
                input_text=f"synthetic prompt {i}", output_text=f"synthetic completion {i}")
            if list(validator.iter_errors(r)):
                print(f"FAIL: emitted receipt {i} schema-invalid", file=sys.stderr)
                return 1
        ok, msg = verify_ledger(ledger, validator)
        if not ok:
            print(f"FAIL: chain should be valid: {msg}", file=sys.stderr)
            return 1
        print(f"OK conformance+chain: {msg}")

        # Tamper -> chain breaks.
        lines = ledger.read_text(encoding="utf-8").splitlines()
        e1 = json.loads(lines[1]); e1["outputHash"] = sha256("tampered")
        lines[1] = canonical(e1)
        ledger.write_text("\n".join(lines) + "\n", encoding="utf-8")
        if verify_ledger(ledger, validator)[0]:
            print("FAIL: tamper not detected — chain has no teeth", file=sys.stderr)
            return 1
        print("OK tamper-evidence: mutation detected")

    # Local-only (unchained, seq>=1 without ledgerPrevHash) rejected by schema + verifier.
    with tempfile.TemporaryDirectory() as d:
        ledger = Path(d) / "local-only.jsonl"
        base = emit_completion_receipt(ledger, base_model_digest=digest, task="t",
                                       input_text="a", output_text="b")
        local_only = dict(base); local_only["ledgerSeq"] = 1
        local_only.pop("ledgerPrevHash", None)
        if not list(validator.iter_errors(local_only)):
            print("FAIL: schema accepted a local-only (unchained) entry", file=sys.stderr)
            return 1
        with ledger.open("a", encoding="utf-8") as f:
            f.write(canonical(local_only) + "\n")
        if verify_ledger(ledger, validator)[0]:
            print("FAIL: verifier accepted a local-only entry (SEAM-011 hole)", file=sys.stderr)
            return 1
        print("OK local-only rejected: schema + verifier both refuse an unchained entry")

    print("PASS: inferenced emit-shim teeth all bite")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="inferenced InferenceReceipt emit shim")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--ledger", type=Path)
    ap.add_argument("--base-model-digest")
    ap.add_argument("--task")
    ap.add_argument("--input-file", type=Path)
    ap.add_argument("--output-file", type=Path)
    ap.add_argument("--compute-device", default="cpu")
    args = ap.parse_args(argv[1:])

    if args.selftest:
        return _selftest()

    missing = [n for n, v in (("--ledger", args.ledger), ("--base-model-digest", args.base_model_digest),
                              ("--task", args.task), ("--input-file", args.input_file),
                              ("--output-file", args.output_file)) if v is None]
    if missing:
        print(f"ERR: missing required args: {', '.join(missing)}", file=sys.stderr)
        return 2
    r = emit_completion_receipt(
        args.ledger, base_model_digest=args.base_model_digest, task=args.task,
        input_text=args.input_file.read_text(encoding="utf-8"),
        output_text=args.output_file.read_text(encoding="utf-8"),
        compute_device=args.compute_device)
    print(json.dumps(r, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
