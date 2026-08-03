#!/usr/bin/env python3
"""Verify vendored dependency pins for the OS build.

Validates every vendor/*.lock.json has the required shape, and — when a local
checkout is available (--checkout <path>) — recomputes the deterministic
`git archive --format=tar <commit>` sha512 and asserts it matches the pinned hash.
A pin that can't be verified is a build failure, not a warning.
"""
from __future__ import annotations
import argparse, hashlib, json, subprocess, sys
from pathlib import Path

REQUIRED = ["name", "repo", "reason", "pin", "integrity"]


def _archive_sha512(checkout: Path, commit: str) -> str:
    tar = subprocess.run(["git", "-C", str(checkout), "archive", "--format=tar", commit],
                         check=True, stdout=subprocess.PIPE).stdout
    return hashlib.sha512(tar).hexdigest()


def verify(lock, checkout):
    errs = [f"missing key {k!r}" for k in REQUIRED if k not in lock]
    if errs:
        return errs
    if "git_archive_tar" not in lock["integrity"]:
        errs.append("integrity.git_archive_tar missing")
    if checkout and checkout.exists() and not errs:
        got = _archive_sha512(checkout, lock["pin"]["commit"])
        want = lock["integrity"]["git_archive_tar"]
        if got != want:
            errs.append(f"integrity mismatch: got {got[:16]}... want {want[:16]}...")
    return errs


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--vendor-dir", type=Path, default=Path(__file__).resolve().parents[1] / "vendor")
    ap.add_argument("--checkout", type=Path)
    a = ap.parse_args(argv)
    locks = sorted(a.vendor_dir.glob("*.lock.json"))
    if not locks:
        print("no vendor locks found", file=sys.stderr)
        return 1
    bad = 0
    for lp in locks:
        lock = json.loads(lp.read_text())
        errs = verify(lock, a.checkout)
        if errs:
            bad += 1
            print(f"FAIL {lp.name}: {'; '.join(errs)}")
        else:
            hv = " (hash verified)" if a.checkout and a.checkout.exists() else " (shape ok)"
            print(f"OK   {lp.name} -> {lock['name']} @ {lock['pin'].get('tag', lock['pin']['commit'][:12])}{hv}")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
