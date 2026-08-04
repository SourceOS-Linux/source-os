#!/usr/bin/env python3
"""Tests for the ADR watch (local advisory + sealed receipts)."""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import adr_watch as w  # noqa: E402

_ADR = {"adr_id": "ADR-0001-nix-to-guix", "kind": "swap", "status": "parity",
        "from": {"lang": "nix", "globs": ["*.nix"]}, "to": {"lang": "guix", "globs": ["*.scm"]},
        "scope": [], "parity_doc": "guix/NIX_BASELINE.md", "waivers": []}


def test_advise_on_a_new_nix_warns_and_seals():
    r = w.advise(["packages/new.nix"], [_ADR])
    assert r["disposition"] == "advisory-warn" and len(r["violations"]) == 1
    assert r["receipt_digest"].startswith("sha256:") and r["surface"].startswith("sourceos.adr_watch")


def test_advise_on_a_scm_is_clear():
    r = w.advise(["guix/system/new.scm"], [_ADR])
    assert r["disposition"] == "advisory-clear" and r["violations"] == []


def test_from_files_in_finds_only_from_side_files():
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / "packages").mkdir()
        (root / "packages" / "a.nix").write_text("{}")
        (root / "guix").mkdir()
        (root / "guix" / "b.scm").write_text(";;")
        (root / "README.md").write_text("#")
        found = w.from_files_in(root, [_ADR])
        assert found == {"packages/a.nix"}


def test_receipt_is_persisted_when_a_dir_is_given():
    with tempfile.TemporaryDirectory() as td:
        r = w.advise(["x.nix"], [_ADR], receipts_dir=td)
        files = list(Path(td).glob("adr-watch-*.json"))
        assert len(files) == 1
        import json
        assert json.loads(files[0].read_text())["receipt_digest"] == r["receipt_digest"]


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    for fn in fns:
        fn()
    print(f"ok: {len(fns)} adr-watch tests passed")
    sys.exit(0)
