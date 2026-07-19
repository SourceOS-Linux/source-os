# World-Class SourceOS and Mac-on-Linux Gap Plan

This document consolidates the current Mac-on-Linux / world-class SourceOS gap
analysis into a single actionable specification and plan. It is a docs-only
planning artifact. It does not claim full macOS parity or world-class OS
readiness.

---

## Tier definitions

Three tiers are distinguished throughout this document. Each has its own scope,
acceptance bar, and repo ownership.

### Tier 1 — Mac-like GNOME workstation v0

**What it means:** A credible GNOME desktop that feels familiar to a macOS user
through bounded keyboard shortcuts, appearance defaults, touchpad gestures,
launcher behavior, and file navigation. No GNOME Shell fork. No proprietary
assets. No claim of feature-for-feature macOS parity.

**Acceptance bar:** The features in `docs/workstation/mac-on-linux-acceptance.md`
reach `implemented` or `validation-backed` status and pass CI smoke checks.

**Current status:** In progress. Several features are `implemented` or
`validation-backed`. Several items remain `planned`. See the acceptance matrix
for detail.

### Tier 2 — macOS parity

**What it means:** Matching a substantial portion of macOS UX, runtime, and
platform behaviors — including continuity features, iCloud-equivalent storage,
Handoff, AirDrop, signed/notarized application trust, accessibility parity,
full localization, and native-feel developer toolchains.

**Current status:** Not attempted. Full macOS parity is a **non-goal** for
workstation-v0 and for the current SourceOS roadmap. This document does not
claim or target macOS parity.

### Tier 3 — world-class OS

**What it means:** An OS that competes on the following dimensions: runtime
integrity and verified boot, hardware lifecycle and firmware management, complete
backup and recovery, cryptographic identity and trust envelope, cross-device
continuity equivalents, accessible and fully localized UI, a stable and audited
contract canon for agents and host interfaces, evidence and reporting pipelines,
and a viable developer/user ecosystem.

**Current status:** Not achieved. Design gaps are documented below. This
document does not claim world-class OS status.

---

## What is already landed

### `SociOS-Linux/source-os`

| Area | Evidence |
|---|---|
| GNOME appearance defaults | `profiles/linux-dev/workstation-v0/gnome/appearance-apply.sh` |
| Mac-style keyboard shortcuts | `profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh` |
| Screenshot bindings | `profiles/linux-dev/workstation-v0/bin/mac-screenshot.sh` |
| Launcher (SourceOS palette on `Super+Space`) | `profiles/linux-dev/workstation-v0/gnome/palette-hotkey.sh` |
| Finder-like sidebar bookmarks | `profiles/linux-dev/workstation-v0/gnome/files-sidebar.sh` |
| Touchpad gestures via Fusuma | `profiles/linux-dev/workstation-v0/gnome/fusuma-install.sh` |
| `input-remapper` keyboard backend | `profiles/linux-dev/workstation-v0/gnome/input-install.sh` |
| `xremap` compatibility lane | same as above |
| Lampstand-backed local file search | `profiles/linux-dev/workstation-v0/bin/sourceos-search.sh` |
| Aggregate polish validation | `profiles/linux-dev/workstation-v0/bin/check-workstation-polish.sh` |
| `sourceos status` / `sourceos doctor` CLI | `profiles/linux-dev/workstation-v0/bin/sourceos` |
| CI smoke workflows (keyboard, polish, Lampstand) | `.github/workflows/` |

### `SourceOS-Linux/sourceos-spec`

| Area | Notes |
|---|---|
| Contract canon drafts | Exists as the authoritative specification repository for SourceOS contracts. |
| Agent Machine interface drafts | Tracked in sourceos-spec; not fully ratified. |

---

## What the design missed — gap catalogue

The following areas have no or insufficient coverage in the current repositories.
Each gap is assigned a tier and a priority (P1 = blocking for next milestone,
P2 = important but not blocking, P3 = future).

### Shell runtime and lifecycle (P1 — Tier 3)

`SourceOS-Linux/sourceos-shell` **already exists** and is the designated repo
for the PDF-first / document-first runtime lane. The next required move is
**not** repo creation. It is:

- Populating `sourceos-shell` with the PDF-first runtime primitives.
- Aligning `sourceos-shell` with the `source-os` workstation profile and the
  `sourceos-spec` contract canon.
- Defining the handoff protocol between `sourceos-shell` and the `sourceos`
  launcher in `source-os`.

Gap: No content exists yet in `sourceos-shell` that demonstrates a working
runtime lane. No alignment document exists between the three repos.

### Backup and recovery (P1 — Tier 3)

Gap: No backup strategy, tooling, or runbook exists for the SourceOS workstation
profile. A world-class OS requires:

- Automated, verifiable backup of user data and system state.
- Recovery runbook tested against at least one hardware target.
- Integration with `sourceos doctor` to report backup health.

### Security and trust envelope (P1 — Tier 3)

Gap: The current profile applies GNOME defaults and package installs without a
defined trust model. Required work:

- Verified / measured boot integration plan (TPM, Secure Boot, image signing).
- Application signing and attestation policy.
- Audit of helper scripts for privilege escalation paths.
- Key/credential lifecycle — generation, rotation, revocation.

### Continuity equivalents (P2 — Tier 2 / 3)

Gap: macOS Continuity (Handoff, AirDrop, Universal Clipboard, iPhone Mirroring)
has no Linux-native equivalent in the profile. A world-class SourceOS could
define bounded equivalents:

- Cross-device clipboard via a defined agent protocol.
- File transfer via an open, auditable channel.
- Notification bridging between workstation and mobile/tablet.

### Contract canon and Agent Machine interface (P1 — Tier 3)

Gap: `sourceos-spec` holds draft contracts but they are not ratified, versioned,
or enforced by `source-os` or `sourceos-shell`. Required work:

- Publish a v0 contract schema for the Agent Machine / secure host interface.
- Require `source-os` and `sourceos-shell` to validate against the schema in CI.
- Define the lifecycle of a contract (proposal → draft → candidate → ratified).

### PDF and document runtime (P1 — Tier 3, `sourceos-shell` lane)

Gap: The PDF-first / document-first runtime is a stated SourceOS differentiator
but no implementation exists. `sourceos-shell` is the designated home.
Required work:

- Define what "PDF-first runtime" means operationally (open format, viewer,
  annotation, signing, archival).
- Implement a minimal working lane in `sourceos-shell`.
- Document the handoff to `source-os` workstation profile.

### Application and runtime trust (P2 — Tier 3)

Gap: No policy exists for what software may run on a SourceOS workstation, how
it is verified, or how sandboxing is applied. Required work:

- Flatpak / OSTree / Nix trust policy document.
- Runtime integrity check integrated with `sourceos doctor`.
- Capability-based permission model sketch for agent-invoked processes.

### Accessibility and localization (P2 — Tier 2 / 3)

Gap: No accessibility audit or localization plan exists. The profile applies
GNOME defaults (which have reasonable a11y support) but does not test, document,
or extend it. Required work:

- GNOME a11y settings applied by `appearance-apply.sh` or a dedicated helper.
- At least one locale other than `en_US` tested and documented.
- WCAG audit note on any custom UI surfaces (launcher, palette).

**Acceptance gate:**
```bash
test -s docs/workstation/accessibility.md
```

### Evidence and reporting (P2 — Tier 3)

Gap: `sourceos doctor --json` and `sourceos status` emit signals, but there is
no pipeline that aggregates evidence across all repos, surfaces a dashboard, or
feeds a release gate. Required work:

- Define the evidence schema for a SourceOS release gate.
- Wire `source-os`, `sourceos-spec`, and `sourceos-shell` CI into a shared
  evidence collection step.
- Produce a human-readable maturity report on each milestone boundary.

---

## Parity scorecard — current state

The following table uses the same status vocabulary as the acceptance matrix.

| Domain | Tier 1 v0 | Tier 2 (parity) | Tier 3 (world-class) |
|---|---|---|---|
| GNOME appearance | validation-backed | not attempted | not attempted |
| Keyboard shortcuts | validation-backed | partial (Kinto planned) | not attempted |
| Touchpad gestures | implemented | partial | not attempted |
| Launcher / palette | implemented | not attempted | not attempted |
| Local file search | validation-backed | not attempted | not attempted |
| Screenshot | validation-backed | not attempted | not attempted |
| Status / doctor CLI | validation-backed | not attempted | not attempted |
| Shell runtime lane | not started | not started | gap (see above) |
| PDF / document runtime | not started | not started | gap (see above) |
| Backup / recovery | not started | not started | gap (see above) |
| Security / trust envelope | not started | not started | gap (see above) |
| Continuity equivalents | not attempted | not attempted | gap (see above) |
| Contract canon | draft only | draft only | gap (see above) |
| Agent Machine interface | draft only | draft only | gap (see above) |
| App / runtime trust | not started | not started | gap (see above) |
| Accessibility | GNOME defaults only | not audited | gap (see above) |
| Localization | not started | not started | gap (see above) |
| Evidence / reporting | partial (CI only) | not started | gap (see above) |

**Overall maturity rating: Tier 1 in progress. Tier 2 and Tier 3 not yet
attempted. This is not a world-class OS claim.**

---

## Repo ownership boundaries

| Repo | Owns | Does not own |
|---|---|---|
| `SociOS-Linux/source-os` | Workstation profile realization; GNOME helpers; `sourceos` CLI; CI smoke workflows; workstation docs | Contract canon; shell runtime primitives; spec ratification |
| `SourceOS-Linux/sourceos-spec` | Contract canon; schema definitions; Agent Machine interface spec; ratification lifecycle | Concrete realization scripts; CI for the workstation profile |
| `SourceOS-Linux/sourceos-shell` | PDF-first / document-first runtime lane; shell runtime primitives; alignment with sourceos-spec contracts | GNOME-specific helpers; workstation package manifests |
| SocioProphet agent / control-plane repos | Agent orchestration; secure host interface implementation; agent lifecycle | OS-level scripts; workstation profile; contract authorship |

### Alignment requirement

A gap exists today: the three primary repos (`source-os`, `sourceos-spec`,
`sourceos-shell`) have no shared alignment document and no cross-repo CI
enforcement of contracts. The next milestone must produce:

1. A tri-repo alignment note (can live in `sourceos-spec`).
2. A contract validation step in `source-os` CI that imports a schema from
   `sourceos-spec`.
3. A `sourceos-shell` README that references the alignment and defines its
   runtime lane scope.

---

## Execution plan — near-term work packets

Work packets are listed in priority order. Each packet has an acceptance gate
that defines done.

### WP-1: `sourceos-shell` bootstrap and alignment (P1)

**Owner:** `SourceOS-Linux/sourceos-shell` primary + `SociOS-Linux/source-os`
alignment change.

**Work:**
- Add a `README.md` to `sourceos-shell` that states the PDF-first runtime lane
  scope and references `sourceos-spec` for the contract canon.
- Add an alignment section to `sourceos-spec` that names all three repos and
  their boundaries (as above).
- Add a stub `docs/runtime-lane.md` to `sourceos-shell` with a minimal
  definition of "PDF-first runtime" and the planned handoff to `source-os`.

**Acceptance gate:**
```bash
test -s README.md                        # in sourceos-shell
test -s docs/runtime-lane.md            # in sourceos-shell
grep -F "sourceos-shell" sourceos-spec/docs/alignment.md
```

### WP-2: Contract canon v0 (P1)

**Owner:** `SourceOS-Linux/sourceos-spec`.

**Work:**
- Publish a `contracts/v0/agent-machine.json` (or YAML) schema.
- Define the ratification lifecycle in `docs/contract-lifecycle.md`.
- Add a CI step that lints the schema against its own meta-schema.

**Acceptance gate:**
```bash
test -s contracts/v0/agent-machine.json  # in sourceos-spec
test -s docs/contract-lifecycle.md       # in sourceos-spec
# CI lint step passes
```

### WP-3: Doctor integration for aggregate polish (P1)

**Owner:** `SociOS-Linux/source-os` (tracked in issue #120).

**Work:**
- Wire `check-workstation-polish.sh` output into `sourceos doctor --json`.
- Ensure `sourceos doctor` exits non-zero when a required polish check fails.

**Acceptance gate:** `sourceos doctor --json` includes a `workstation_polish`
key and the CI workflow for doctor passes.

### WP-4: Backup and recovery runbook (P1)

**Owner:** `SociOS-Linux/source-os`.

**Work:**
- Add `docs/workstation/backup-recovery.md` describing the backup strategy,
  tooling choices, and recovery steps.
- Add a validation helper `profiles/linux-dev/workstation-v0/bin/check-backup.sh`
  that emits a warning when no backup target is configured.

**Acceptance gate:**
```bash
test -s docs/workstation/backup-recovery.md
bash -n profiles/linux-dev/workstation-v0/bin/check-backup.sh
```

### WP-5: Security and trust envelope plan (P1)

**Owner:** `SociOS-Linux/source-os` (doc) + `SourceOS-Linux/sourceos-spec`
(trust model schema).

**Work:**
- Add `docs/workstation/security-trust.md` covering verified boot, app signing,
  and credential lifecycle at the plan level.
- Reference the trust model from `sourceos-spec`.

**Acceptance gate:**
```bash
test -s docs/workstation/security-trust.md
grep -F "Secure Boot" docs/workstation/security-trust.md
```

### WP-6: Dock and extension validation helper (P2)

**Owner:** `SociOS-Linux/source-os` (tracked in issue #130).

**Work:** Implement `bin/check-dock-extensions.sh` and wire into the aggregate
polish workflow.

**Acceptance gate:** Workflow passes; helper exits 0 on a correctly configured
GNOME session.

### WP-7: Shortcut map contract (P2)

**Owner:** `SociOS-Linux/source-os` (tracked in issue #126).

**Work:** Publish `docs/workstation/shortcut-map-contract.md` and validate
against current `mac-defaults.sh` bindings.

**Acceptance gate:**
```bash
test -s docs/workstation/shortcut-map-contract.md
```

### WP-8: Accessibility baseline (P2)

**Owner:** `SociOS-Linux/source-os`.

**Work:** Add an a11y settings block to `appearance-apply.sh` (high-contrast
toggle, screen reader note) and a `docs/workstation/accessibility.md` audit
note.

**Acceptance gate:**
```bash
test -s docs/workstation/accessibility.md
```

### WP-9: Evidence and reporting schema (P2)

**Owner:** `SourceOS-Linux/sourceos-spec` (schema) + `SociOS-Linux/source-os`
(CI wire-up).

**Work:** Define an evidence schema and produce a milestone maturity report from
CI outputs.

**Acceptance gate:** A `reports/milestone-N.json` artifact is produced by CI and
passes schema validation.

---

## Non-goals preserved

- No full macOS UI clone.
- No GNOME Shell fork or libadwaita replacement.
- No proprietary asset dependency.
- No production readiness claim from this document.
- No claim of full macOS parity.
- No world-class OS claim until Tier 3 gaps are closed and evidence exists.

---

## Validation

```bash
test -s docs/workstation/world-class-sourceos-parity-plan.md
grep -F "sourceos-shell already exists" docs/workstation/world-class-sourceos-parity-plan.md
grep -F "Mac-like GNOME workstation v0" docs/workstation/world-class-sourceos-parity-plan.md
grep -F "world-class OS" docs/workstation/world-class-sourceos-parity-plan.md
```
