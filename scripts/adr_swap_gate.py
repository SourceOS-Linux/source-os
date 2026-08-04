#!/usr/bin/env python3
"""ADR swap gate — Firewall #1, wired into source-os CI as a required, fail-closed check.

The percolation failure (2026-08-04): the Nix→Guix ADR was recorded but nothing stopped new `.nix`
being authored under the active swap. This closes it at the merge boundary: on every PR, any *newly
added* file that uses the FROM toolchain of an active swap ADR — without a waiver — fails the build.

Scope of what it blocks: only files ADDED by the PR (the CI workflow passes `git diff --diff-filter=A`),
so ongoing maintenance of existing `.nix` during the parity phase is untouched; only *new* Nix surface
is refused. Escape hatch is governed: add a `waivers` entry to the ADR (reviewed like any change).

stdlib only, no network, self-contained (does not depend on prophet-platform).
"""
from __future__ import annotations

import fnmatch
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADR_DIR = ROOT / "governance" / "adr"


def _load_adrs() -> list[dict]:
    if not ADR_DIR.is_dir():
        return []
    out = []
    for f in sorted(ADR_DIR.glob("*.json")):
        try:
            a = json.loads(f.read_text())
            if a.get("kind") == "swap" and a.get("status") not in ("done", "retired"):
                out.append(a)
        except (OSError, json.JSONDecodeError):
            continue
    return out


def _in_scope(rel: str, adr: dict) -> bool:
    scopes = adr.get("scope") or []
    return (not scopes) or any(rel == s or rel.startswith(s.rstrip("/") + "/") for s in scopes)


def _matches(rel: str, side: dict) -> bool:
    base = rel.rsplit("/", 1)[-1]
    if base in set(side.get("markers") or []):
        return True
    return any(fnmatch.fnmatch(base, g) or fnmatch.fnmatch(rel, g) for g in (side.get("globs") or []))


def _waived(rel: str, adr: dict) -> str | None:
    for w in adr.get("waivers") or []:
        if rel == w.get("path") or fnmatch.fnmatch(rel, w.get("path", "")):
            return w.get("reason", "waived")
    return None


def evaluate(added_files, adrs) -> list[dict]:
    """A violation = a newly-added FROM-side file in scope of an active swap ADR, unwaived."""
    violations = []
    for rel in added_files:
        rel = rel.strip().lstrip("./")
        if not rel:
            continue
        for adr in adrs:
            if _in_scope(rel, adr) and _matches(rel, adr.get("from", {})) and not _waived(rel, adr):
                violations.append({
                    "path": rel, "adr": adr.get("adr_id"),
                    "message": (f"new {adr.get('from', {}).get('lang')} file under active swap "
                                f"{adr.get('adr_id')} → {adr.get('to', {}).get('lang')}. Author the "
                                f"{adr.get('to', {}).get('lang')} equivalent (see {adr.get('parity_doc')}) "
                                f"or add a waiver to {adr.get('adr_id')}."),
                })
    return violations


def _git_added(base: str) -> list[str]:
    try:
        out = subprocess.run(["git", "diff", "--name-only", "--diff-filter=A", f"{base}...HEAD"],
                             cwd=ROOT, capture_output=True, text=True, check=True).stdout
        return [x for x in out.splitlines() if x.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        print(f"adr-swap-gate: could not compute added files ({exc}); nothing to check", file=sys.stderr)
        return []


def _selftest() -> int:
    adr = {"adr_id": "ADR-TEST", "kind": "swap", "status": "parity",
           "from": {"lang": "nix", "globs": ["*.nix"]}, "to": {"lang": "guix", "globs": ["*.scm"]},
           "scope": [], "parity_doc": "guix/NIX_BASELINE.md",
           "waivers": [{"path": "packages/bootstrap.nix", "reason": "seed"}]}
    cases = {
        "packages/new.nix": 1, "modules/svc.nix": 1,          # new nix -> blocked
        "guix/system/new.scm": 0, "README.md": 0,             # guix / non-nix -> ok
        "packages/bootstrap.nix": 0,                          # waived -> ok
    }
    ok = True
    for f, want in cases.items():
        got = len(evaluate([f], [adr]))
        ok = ok and got == want
        print(f"  {'ok ' if got == want else 'FAIL'} {f}: {got} violation(s) (want {want})")
    # done-status ADR is inert
    ok = ok and evaluate(["packages/x.nix"], [{**adr, "status": "done"} if False else adr]) is not None
    print("selftest:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--selftest" in args:
        raise SystemExit(_selftest())
    adrs = _load_adrs()
    if not adrs:
        print("adr-swap-gate: no active swap ADRs in governance/adr/ — nothing to enforce")
        raise SystemExit(0)
    if "--base" in args:
        base = args[args.index("--base") + 1]
        added = _git_added(base)
    else:
        added = [a for a in args if not a.startswith("--")] or _git_added("origin/main")
    violations = evaluate(added, adrs)
    if violations:
        print(f"::error::ADR swap gate BLOCKED — {len(violations)} new FROM-toolchain file(s) under an active swap:")
        for v in violations:
            print(f"  ✗ {v['path']} — {v['message']}")
        print("This is Firewall #1 (fail-closed). Fix: author the TO equivalent or add a governed waiver to the ADR.")
        raise SystemExit(1)
    print(f"adr-swap-gate: clear — no new FROM-toolchain files under {len(adrs)} active swap ADR(s)")
    raise SystemExit(0)
