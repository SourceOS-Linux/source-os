Use the GitHub issue body as the complete source of truth.

Copilot is the primary executor for bounded issue-first PR work in this repository. The issue body must contain the full task, acceptance criteria, validation commands, and non-goals before assignment. Do not rely on later comments as required context.

Before editing:

1. Read the issue body.
2. Inspect the repository.
3. Identify existing validation commands.
4. Keep the PR bounded to the issue scope.

When implementing:

- Prefer existing repository patterns.
- Add tests, fixtures, validators, or documentation with the implementation when appropriate.
- Keep generated files only if repository conventions require them.
- Do not modify unrelated workflows or policy files.
- Do not touch unrelated repositories.
- Do not broaden scope without asking in the issue.
- Do not claim production readiness unless the issue explicitly requests and acceptance criteria prove it.
- Open one PR against the default branch unless the issue explicitly says otherwise.

When opening the PR:

- Link the issue.
- Include what changed.
- Include exact validation commands run.
- Include pass/fail output summary.
- List known gaps.
- State non-goals preserved.
- State anything blocked.
- Do not mark ready if validation did not run.

Delivery evidence:

- A PR, branch, commit, or merge must exist in GitHub to count as delivery.
- Comments, local task summaries, and draft notes are not delivery artifacts by themselves.
- If blocked from creating a PR, report the blocker clearly on the issue.

SourceOS-specific boundaries:

- Be conservative around boot, install, recovery, host mutation, release automation, and runtime admission.
- Do not change privileged workflows unless the issue explicitly asks for workflow work.
- Do not add secrets, credentials, private keys, tokens, or signing material.
- Keep Mac-on-Linux workstation work bounded to documented GNOME defaults, helper scripts, validation helpers, package declarations, and docs unless the issue explicitly requests deeper changes.
- Distinguish active behavior from future or proposed parity claims.
- Preserve existing JSON contracts unless the issue explicitly requests a schema change.

Validation expectations:

- Run repo-native validation when available.
- For shell scripts, run `bash -n` and any existing smoke workflows/tests relevant to the changed path.
- For JSON examples or schemas, run `python3 -m json.tool` or repo-native schema validation.
- If a validation command cannot run, explain why and include the error.
