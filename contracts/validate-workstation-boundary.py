#!/usr/bin/env python3
"""Validate WorkstationActionBoundary records against the lifecycle-boundary contract.

Usage:
    python3 contracts/validate-workstation-boundary.py <record.json> [<record.json> ...]

Exits 0 if all records pass. Exits 1 if any fail.
"""

import json
import sys

MUTATION_FREE_KINDS = {"doctor_report", "fix_plan"}
MUTATION_REQUIRED_KINDS = {"applied_fix"}
POLICY_REQUIRED_KINDS = {"applied_fix", "admission_decision"}


def validate(path):
    errors = []
    try:
        with open(path) as f:
            r = json.load(f)
    except Exception as e:
        return [f"parse error: {e}"]

    kind = r.get("artifact_kind", "")
    mutation_performed = r.get("mutation_performed", False)
    mutation_planned = r.get("mutation_planned", False)

    # doctor/report/fix-plan must never claim mutation_performed
    if kind in MUTATION_FREE_KINDS and mutation_performed:
        errors.append(
            f"FAIL [{kind}]: mutation_performed=true is forbidden for {kind}. "
            "A doctor/report/fix-plan artifact must not imply a mutation was executed."
        )

    # applied_fix must claim mutation_performed
    if kind in MUTATION_REQUIRED_KINDS and not mutation_performed:
        errors.append(
            f"FAIL [{kind}]: mutation_performed=false for applied_fix. "
            "An applied_fix record must confirm the mutation occurred."
        )

    # mutation requires policy refs
    if mutation_performed and not r.get("policy_decision_refs"):
        errors.append(
            "FAIL: mutation_performed=true but policy_decision_refs is empty. "
            "Every mutation requires an explicit policy/admission decision ref."
        )

    # mutation requires before/after evidence
    if mutation_performed and not r.get("before_refs"):
        errors.append("FAIL: mutation_performed=true but before_refs is empty.")
    if mutation_performed and not r.get("after_refs"):
        errors.append("FAIL: mutation_performed=true but after_refs is empty.")

    # mutation requires performed_by
    if mutation_performed and not r.get("performed_by"):
        errors.append("FAIL: mutation_performed=true but performed_by is missing.")

    # fix_plan without policy refs is fine — it's a plan, not a decision
    # but fix_plan claiming mutation_planned=false is suspicious
    if kind == "fix_plan" and not mutation_planned:
        errors.append(
            "WARN [fix_plan]: mutation_planned=false on a fix_plan. "
            "A fix plan that proposes no mutation is likely a doctor_report."
        )

    # sensitive data must be excluded
    if r.get("sensitive_data_excluded") is not True:
        errors.append(
            "FAIL: sensitive_data_excluded must be true. "
            "Raw credentials, prompt content, and private keys must not appear in boundary records."
        )

    return errors


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <record.json> [...]")
        sys.exit(2)

    overall_pass = True
    for path in sys.argv[1:]:
        errors = validate(path)
        if errors:
            overall_pass = False
            print(f"\n{path}: FAIL")
            for e in errors:
                print(f"  {e}")
        else:
            print(f"{path}: OK")

    sys.exit(0 if overall_pass else 1)


if __name__ == "__main__":
    main()
