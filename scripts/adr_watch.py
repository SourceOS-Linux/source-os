#!/usr/bin/env python3
"""ADR watch — the fast, local, ADVISORY half of Firewall #1 (inner loop), + the sealed-receipt stream.

The CI gate (adr_swap_gate.py / .github/workflows/adr-swap-gate.yml) is the AUTHORITATIVE, fail-closed
control — it gates merges. This is its inner-loop companion: it watches the working tree locally and,
the moment a new FROM-toolchain file (e.g. a `.nix` under the active Guix swap) appears, it warns —
so you find out at author-time, not at PR time. It is advisory by design (a local watcher is racy and
must never be the thing that gates); its durable output is a **sealed receipt** per event, the stream a
pump later feeds into the always-on HellGraph service for graph-native RCA.

Two layers, deliberately: local watch = fast advisory; CI = authoritative. stdlib only, no watchdog.
"""
from __future__ import annotations

import hashlib
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import adr_swap_gate as gate


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _seal(body: dict) -> str:
    return "sha256:" + hashlib.sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def from_files_in(root: Path, adrs: list) -> set[str]:
    """Every FROM-side, in-scope file currently present under root (relative paths)."""
    out: set[str] = set()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules", "result")]
        for fn in filenames:
            rel = str(Path(dirpath, fn).relative_to(root))
            for adr in adrs:
                if gate._in_scope(rel, adr) and gate._matches(rel, adr.get("from", {})) \
                        and not gate._waived(rel, adr):
                    out.add(rel)
                    break
    return out


def advise(added: list[str], adrs: list, *, receipts_dir=None) -> dict:
    """Evaluate newly-appeared files against the active swap ADRs and seal an advisory receipt. Never
    raises, never blocks — it warns and records."""
    violations = gate.evaluate(added, adrs)
    receipt = {
        "surface": "sourceos.adr_watch.advisory.v1", "decided_at": _now(),
        "added": sorted(added), "violations": violations,
        "adrs": [a.get("adr_id") for a in adrs],
        "disposition": "advisory-warn" if violations else "advisory-clear",
    }
    receipt["receipt_digest"] = _seal({k: v for k, v in receipt.items() if k != "receipt_digest"})
    if receipts_dir is not None:
        d = Path(receipts_dir)
        d.mkdir(parents=True, exist_ok=True)
        (d / f"adr-watch-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f')}-"
             f"{receipt['receipt_digest'][7:19]}.json").write_text(json.dumps(receipt, indent=2))
    return receipt


def _print(receipt: dict) -> None:
    if receipt["violations"]:
        print(f"⚠️  adr-watch: {len(receipt['violations'])} new FROM-toolchain file(s) — advisory "
              f"(CI will block this):")
        for v in receipt["violations"]:
            print(f"   ✗ {v['path']} — {v['message']}")
    else:
        print(f"adr-watch: clear ({len(receipt['added'])} new file(s) checked)")


def watch(root: Path, adrs: list, *, interval: float = 2.0, receipts_dir=None) -> None:
    baseline = from_files_in(root, adrs)
    print(f"adr-watch: watching {root} for new FROM-toolchain files under "
          f"{[a.get('adr_id') for a in adrs]} (Ctrl-C to stop; advisory only)")
    try:
        while True:
            time.sleep(interval)
            cur = from_files_in(root, adrs)
            new = sorted(cur - baseline)
            if new:
                _print(advise(new, adrs, receipts_dir=receipts_dir))
            baseline = cur
    except KeyboardInterrupt:
        print("\nadr-watch: stopped")


if __name__ == "__main__":
    import sys

    root = Path(gate.ROOT)
    adrs = gate._load_adrs()
    receipts = root / "artifacts" / "adr-receipts"
    if not adrs:
        print("adr-watch: no active swap ADRs — nothing to watch")
        raise SystemExit(0)
    args = sys.argv[1:]
    if "--watch" in args:
        iv = float(args[args.index("--interval") + 1]) if "--interval" in args else 2.0
        watch(root, adrs, interval=iv, receipts_dir=receipts)
    else:
        # --once: advise on the files the PR added (or explicit args), emit a receipt, never block.
        added = [a for a in args if not a.startswith("--")]
        if not added:
            base = args[args.index("--base") + 1] if "--base" in args else "origin/main"
            added = gate._git_added(base)
        r = advise(added, adrs, receipts_dir=receipts)
        _print(r)
        print(f"receipt: {r['receipt_digest']}")
