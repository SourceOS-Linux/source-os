# World-Class SourceOS and Mac-on-Linux Parity Plan

This document integrates the latest workstation-v0 gap analysis into one actionable plan.

It is deliberately conservative. SourceOS may claim progress toward a Mac-like GNOME workstation v0, but it must not claim full macOS parity or world-class OS readiness until the missing product, lifecycle, security, recovery, continuity, and evidence layers are real.

## Executive position

Current maturity estimate:

| Target | Current estimate | Position |
|---|---:|---|
| Mac-like GNOME workstation v0 | 75-80% | Credible, validation-backed local workstation lane. |
| macOS parity | 25-30% | Not close; major ecosystem, continuity, app, security, backup, and product gaps remain. |
| world-class OS | 30-35% | Strong realization spine, but missing full lifecycle/product/runtime/security/recovery plane. |

The immediate posture should be:

- Say **Mac-like GNOME workstation v0** when discussing the landed workstation lane.
- Say **not yet macOS parity** when discussing Apple-equivalent claims.
- Say **not yet world-class OS** until SourceOS has install/update/recovery/backup/security/runtime/contracts/evidence across the full stack.

## Important correction

`SourceOS-Linux/sourceos-shell` already exists.

Therefore the next runtime move is not repo creation. The next runtime move is to populate and validate the PDF-first runtime lane already described by that repository:

- `services/docd` for document derivation;
- `services/pdf-secure` for signing and validation;
- `apps/pdf-viewer-demo` for the viewer/demo surface;
- `content/` for draft, derived, and report layout;
- workspace/bootstrap files, Makefile, and smoke validation;
- contract links back to `SourceOS-Linux/sourceos-spec`;
- Linux realization links back to `SourceOS-Linux/source-os`.

## What is already landed

The workstation-v0 Mac-on-Linux lane now has real implementation or validation surfaces for:

| Area | Landed surface |
|---|---|
| Launcher/action bus | `sourceos palette`, fuzzel/wofi/rofi/fzf fallback policy. |
| Shell/fix/report helpers | `sourceos fix shell`, `fix fish`, `fix all`, report paths. |
| Status/doctor | `sourceos status --json`, `doctor.sh --json`, aggregate polish warnings. |
| Mac polish | screenshot helper, screenshot shortcuts, Quick Look/Sushi support, sidebar bookmarks, appearance defaults. |
| Shortcut contract | `docs/workstation/shortcut-map.md`, `check-shortcut-map-contract.sh`, smoke workflow. |
| Keyboard policy | `input-remapper` primary, `xremap` compatibility, Kinto explicit compatibility, `check-keyboard-policy.sh`. |
| GNOME dock/extension validation | `check-gnome-dock-extension.sh`, smoke workflow. |
| Aggregate validation | `check-workstation-polish.sh` now aggregates Mac polish, keyboard policy, shortcut map, and dock signals. |
| Status integration | `sourceos status` consumes aggregate polish warnings without changing status JSON shape. |
| Doctor integration | `doctor.sh` consumes aggregate polish signals as warning-oriented results without changing doctor JSON shape. |
| Operator docs | `docs/workstation/RUNBOOK.md`, acceptance matrix, shortcut map. |
| Contract alignment | `sourceos-spec` DesktopProfile now has optional Mac-on-Linux polish metadata. |
| Agent instructions | `AGENTS.md` and `.github/copilot-instructions.md` encode issue-first, Copilot-primary delivery policy. |

## What the design missed

### 1. Shell runtime ownership was under-developed

We built Linux realization and validation faster than product runtime. The correct runtime home is `SourceOS-Linux/sourceos-shell`, and it already exists. The missing work is to populate the product/runtime repo with executable services, app shells, package scaffolds, and smoke validation.

### 2. macOS parity was framed too narrowly

Mac-like GNOME is not macOS parity. True parity would require equivalents for:

- Continuity/Handoff class workflows;
- Universal Clipboard;
- AirDrop-like local transfer;
- phone/camera/device bridge surfaces;
- Time Machine-class backup and restore;
- FileVault/Keychain/Gatekeeper-class trust envelope;
- Preview/PDF-quality document UX;
- Messages/Notes/Photos-class application workflows or open equivalents;
- accessibility and localization;
- power, sleep, battery, thermal, and hardware integration;
- app store/package and update trust model.

### 3. Lifecycle and recovery are still not a product

A world-class OS needs first-class:

- install;
- update;
- rollback;
- rescue;
- backup;
- restore;
- snapshot retention;
- user-readable recovery flows;
- health validation before and after update.

The current workstation lane has install and validation helpers, but not a complete lifecycle product.

### 4. Security and trust envelope are incomplete

SourceOS needs an explicit trust model for:

- disk/profile encryption;
- secret storage;
- signed packages and provenance;
- executable trust decisions;
- revocation;
- sandboxing;
- permission prompts;
- policy-bound host/agent mounts;
- secure recovery and attestation.

### 5. Contracts still trail implementation

`sourceos-spec` now represents DesktopProfile Mac-on-Linux polish metadata, but workstation doctor/fix reports still need canonical schemas:

- `WorkstationDoctorReport`;
- `WorkstationFixShellReport`;
- `WorkstationFixFishReport`;
- `WorkstationFixAllReport`.

These are required before `agentplane`, `sociosphere`, `prophet-cli`, and `contractforge` can rely on stable evidence contracts.

### 6. Agent Machine contracts are central, not optional

A world-class agentic OS needs secure contracts for host, VM, container, repo, user, and agent planes. The Agent Machine and secure host interface work is not a side quest. It defines safe terminal/browser/editor/tool access, mount policies, evidence, and TopoLVM/local data semantics.

### 7. The parity scorecard was missing

Without a formal scorecard, claims drift. We need maturity lanes for:

- visual parity;
- interaction parity;
- workflow parity;
- developer parity;
- security parity;
- backup/recovery parity;
- continuity parity;
- accessibility/localization parity;
- operational parity;
- evidence/contract parity.

## Parity scorecard

| Lane | Current maturity | Required to claim parity |
|---|---:|---|
| Visual GNOME polish | Medium | Dock behavior, theme/icon/font policy, window/app switching, consistent defaults. |
| Interaction shortcuts | Medium | GUI/terminal/browser/editor parity fixtures, backend-specific acceptance tests. |
| Launcher/search | Medium | Apps/files/web routing, richer provider routing, no redundant file search proof. |
| File manager / preview | Medium | Quick Look/Sushi done; need richer file metadata, tagging, preview, open-with, search UX. |
| PDF/document UX | Low | `sourceos-shell` PDF-first runtime: docd, pdf-secure, viewer/demo, reports. |
| Backup/recovery | Low | Snapshot, retention, restore UX, disaster recovery, recovery media. |
| Security/trust | Low | encryption, key/secret store, signed provenance, app sandbox/trust prompts. |
| Continuity/device bridge | Very low | open equivalents for clipboard, transfer, camera, phone/device handoff. |
| Accessibility/localization | Very low | keyboard/a11y matrix, screen reader checks, localization policy. |
| OS lifecycle | Low | installer, update, rollback, promotion, channel policy, health gate. |
| Contract/evidence | Medium | DesktopProfile aligned; doctor/fix contracts still missing. |
| Agentic control plane | Low-medium | status/doctor outputs exist; agentplane/sociosphere/prophet-cli ingestion not done. |

## Repository ownership boundaries

| Repository | Owns | Does not own |
|---|---|---|
| `SourceOS-Linux/source-os` | Linux realization, workstation profile, GNOME helpers, installer, doctor/status, host/service wiring. | Product shell runtime, shared contract canon. |
| `SourceOS-Linux/sourceos-spec` | JSON schemas, canonical examples, evidence contracts, workstation report contracts. | Linux implementation scripts or product runtime. |
| `SourceOS-Linux/sourceos-shell` | Product/runtime shell, PDF-first document services, viewer/demo, router/docd/pdf-secure runtime. | Host profile realization or shared schema canon. |
| `SocioProphet/agentplane` | Agent execution evidence, policy/control ingestion, run/replay artifacts. | Local workstation implementation. |
| `SocioProphet/sociosphere` | Operator/workspace UI surfaces for workstation health/action reports. | OS host implementation. |
| `SocioProphet/prophet-cli` | Remote/operator-facing wrappers for audit/fix flows. | SourceOS host profile internals. |
| `SocioProphet/contractforge` | Typed contract generation and validation surfaces. | Runtime ownership. |

## Near-term execution plan

### Phase A — Finish the workstation-v0 validation closure

1. Finish `mac-defaults.sh` validation helper and workflow.
2. Reconcile umbrella tracker progress so stale checkboxes do not distort planning.
3. Ensure acceptance matrix reflects the latest aggregate, status, doctor, shortcut, dock, and spec work.

Acceptance gate:

- Fresh checkout has validation helpers for mac defaults, shortcut map, dock/extensions, Mac polish, keyboard policy, aggregate polish, status JSON shape, doctor JSON shape.

### Phase B — Populate `sourceos-shell` PDF-first runtime

Create or update a bounded issue in `SourceOS-Linux/sourceos-shell` for:

- `services/docd` stub;
- `services/pdf-secure` stub;
- `apps/pdf-viewer-demo` stub;
- content draft/derived/reports layout;
- Makefile and smoke validation;
- README boundary to `sourceos-spec` and `source-os`;
- fixture document flow: draft markdown -> derived PDF/report placeholder.

Acceptance gate:

- `make validate` or equivalent passes.
- Each service/app has a minimal smoke command.
- README states repo boundary.

### Phase C — Canonize workstation reports

In `SourceOS-Linux/sourceos-spec`, finish schemas and examples for:

- `WorkstationDoctorReport`;
- `WorkstationFixShellReport`;
- `WorkstationFixFishReport`;
- `WorkstationFixAllReport`.

Acceptance gate:

- examples validate;
- current `source-os` report shapes can be mapped without breaking existing output.

### Phase D — OS lifecycle and recovery roadmap

Add contracts and realization backlog for:

- install profile;
- update profile;
- rollback profile;
- recovery profile;
- snapshot/backup policy;
- restore report;
- health gates.

Acceptance gate:

- at least one dev-host dry-run lifecycle path exists with evidence output.

### Phase E — Trust envelope roadmap

Define and implement first slices for:

- signed package/update metadata;
- local provenance verification;
- secret store boundary;
- sandbox/app permission policy;
- host/agent mount policy;
- user-readable trust decisions.

Acceptance gate:

- no privileged or host-mutating flow lacks a policy/evidence hook.

### Phase F — Continuity-equivalent roadmap

Design open equivalents for:

- universal clipboard;
- local file transfer;
- camera/phone bridge;
- device handoff;
- workspace sync;
- network/hotspot handoff.

Acceptance gate:

- documented security model and at least one local-first prototype lane.

## Work packet backlog

Highest priority:

1. `source-os`: finish `mac-defaults.sh` validation helper (#102).
2. `sourceos-shell`: add PDF-first runtime scaffold and smoke validation.
3. `sourceos-spec`: add workstation doctor/fix report contracts (#49).
4. `source-os`: reconcile #67 and #77 tracker progress with landed work.
5. `sourceos-spec`: continue Agent Machine / secure host interface contracts (#76/#77/#78).

Secondary priority:

6. `source-os`: dock behavior policy pack: size, hide, click action, magnification policy.
7. `source-os`: xremap activation path and Kinto compatibility docs/tests.
8. `source-os`: richer Fusuma gesture defaults and conflict handling.
9. `source-os`: terminal/editor/browser shortcut acceptance fixtures.
10. `source-os`: theme/icon/font package policy and validation.

Strategic priority:

11. backup/recovery contract and prototype;
12. security/trust envelope contract and prototype;
13. continuity-equivalent architecture;
14. agentplane/sociosphere/prophet-cli ingestion of workstation health reports;
15. sourceos-shell document/PDF UI beyond stubs.

## Claim discipline

Permitted claims now:

- SourceOS has a growing Mac-like GNOME workstation-v0 realization.
- The workstation lane is increasingly validation-backed.
- SourceOS has repo boundaries for realization, contracts, and runtime.

Not permitted yet:

- full macOS parity;
- world-class OS readiness;
- production-grade security envelope;
- Time Machine/FileVault/Continuity/Gatekeeper equivalents;
- mature application/runtime ecosystem;
- complete sourceos-shell runtime.

## Completion criteria for stronger claims

To claim Mac-like GNOME workstation v0:

- all current workstation helper workflows pass;
- fresh-install runbook is validated on a clean GNOME host;
- shortcut/launcher/screenshot/search/preview/status/doctor paths are demoed and documented.

To claim macOS-adjacent workstation:

- add backup/recovery, trust envelope, richer shortcuts, app/file workflow polish, and continuity-equivalent prototypes.

To claim world-class SourceOS:

- complete lifecycle, recovery, security, runtime, contracts, device/hardware integration, accessibility/localization, backup/sync, and agentic evidence integration.

## Immediate next action

Finish #102 before opening broader product work. It is the last narrow validation gap in the GNOME defaults pack and should be handled before we move the center of gravity to `sourceos-shell`.
