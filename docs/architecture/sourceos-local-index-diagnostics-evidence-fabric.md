# SourceOS Local Index, Diagnostics, and Evidence Fabric

Status: proposed
Date: 2026-05-05
Repository owner: `SociOS-Linux/source-os`
Related domains: workstation parity, search, diagnostics, trust envelope, privacy, evidence receipts, agentic OS control plane

## Executive position

SourceOS should not clone Spotlight, Console, or proprietary ecosystem analytics as a monolithic background daemon model. SourceOS should implement a governed local knowledge and diagnostics fabric with explicit daemon ownership, strict resource budgets, signed evidence receipts, local-first privacy defaults, and user-readable explanations for every expensive or sensitive action.

The observed failure pattern from the macOS diagnostic artifacts is instructive:

- indexing and analytics surfaces expose useful counters and operational state;
- background analytics can exceed CPU thresholds without enforcement;
- daemon call paths can fan out through XPC, code-signing validation, filesystem traversal, cloud-document path resolution, OS log reflection, JSON serialization, and UI diagnostics;
- user-facing explanations remain too indirect to answer simple questions such as what woke, why it woke, which files were involved, whether cloud paths were touched, and what action was taken.

SourceOS should steal the product lesson but reject the architecture smell.

## Decision

SourceOS will define local indexing, diagnostics, trust validation, health observation, and receipt emission as separate bounded services. No background service may both observe broadly and act broadly. No analytics path may implicitly traverse user content, cloud state, or executable trust surfaces. Every expensive or privacy-sensitive operation must have an actor, object, operation, policy, receipt, and resource-budget outcome.

The implementation target is a five-plane local fabric:

1. `sourceos-fs-eventd` — filesystem and volume event ingestion.
2. `sourceos-indexd` — local index orchestration and materialized search indexes.
3. `sourceos-trustd` — package, binary, extractor, image, and update provenance verification.
4. `sourceos-healthd` — resource pressure, daemon budget, and service-state observation.
5. `sourceos-receiptd` — durable local receipts for indexing, policy, trust, sync, and diagnostic actions.

These services integrate with `sourceos status`, `doctor.sh`, workstation reports, the shell runtime, and future `agentplane` / `sociosphere` / `prophet-cli` ingestion paths.

## Non-goals

This ADR does not require a final search UI implementation.

This ADR does not require remote analytics.

This ADR does not permit cloud upload, semantic embedding, backup, or sync merely because a file was indexed.

This ADR does not put trust verification, cloud sync, analytics, and indexing in one daemon.

This ADR does not claim full macOS parity. It defines one required substrate for eventually making such claims responsibly.

## Design principles

### 1. Local first by default

Indexing is local unless the user has signed an explicit policy permitting sync, backup, semantic embedding, remote inference, or external publication.

### 2. One daemon, one job

Each daemon has a small authority envelope. Broad observation and broad mutation must not live in the same process.

### 3. Receipts before claims

If SourceOS claims a file was indexed, skipped, denied, quarantined, embedded, synced, signed, or restored, the system must be able to produce a compact receipt explaining the event.

### 4. Unknown is a defect state

Unknown actors, unknown origins, unknown policy basis, unknown extractor identity, and unknown data egress are permitted only as degraded findings. They must appear in health reports.

### 5. Diagnostics cannot become the outage

Observation tools must have their own budgets. A Console-like or doctor-like observer must not amplify system load through unbounded log reflection, UI rendering, or diagnostic polling.

### 6. Cloud is a separate policy plane

Cloud-backed folders, sync mounts, remote object stores, and backup targets are not ordinary local folders. They carry explicit volume policy and exposure receipts.

### 7. Search results must be explainable

A user must be able to ask why a result appeared and receive the path, content span, extractor version, index generation, policy basis, and privacy state.

## Plane design

### `sourceos-fs-eventd`

Responsibilities:

- ingest filesystem events from Linux-native mechanisms such as `fanotify`, `inotify`, mount notifications, and filesystem-specific journal surfaces where available;
- normalize events into a stable event ledger;
- attach actor context when available: UID, process, cgroup, systemd unit, container, Flatpak app ID, package transaction, sync daemon, or unknown;
- deduplicate, batch, and rate-limit event storms;
- distinguish user action, application action, package transaction, sync pull, sync push, removable media event, and system update;
- emit events to the receipt and index planes.

Must not:

- parse file contents;
- generate embeddings;
- send analytics;
- contact cloud services;
- perform code-signing or package-trust traversal inline.

### `sourceos-indexd`

Responsibilities:

- consume normalized events;
- apply per-volume and per-path indexing policy;
- dispatch sandboxed extractors by MIME type;
- materialize full-text, metadata, vector, and graph indexes;
- emit receipts for indexed, skipped, failed, quarantined, and policy-denied items;
- expose `sourceos index status` and machine-readable health output.

Must not:

- own cloud sync;
- inline trust validation beyond calling `sourceos-trustd`;
- hold ambient read access to all user content without policy;
- run unbounded extractors in-process;
- perform remote inference by default.

Recommended storage split:

| Layer | Workstation default | Fog / multi-user option | Purpose |
|---|---|---|---|
| Event ledger | SQLite or append-only JSONL/CBOR | PostgreSQL / object-backed log | durable source of truth |
| Text index | Tantivy or Xapian | Tantivy/Xapian shard workers | lexical search |
| Metadata | SQLite | PostgreSQL | path, MIME, actor, volume, policy |
| Analytics/inspection | DuckDB optional | DuckDB / columnar warehouse | local diagnostics and reports |
| Vectors | LanceDB or Qdrant local | Qdrant / LanceDB service | semantic retrieval under policy |
| Graph/RDF | Oxigraph or property-graph adapter | Oxigraph / TerminusDB-style service | semantic relations and provenance |

### `sourceos-trustd`

Responsibilities:

- verify package provenance, rpm-ostree commits, Flatpak metadata, OCI image signatures, extractor provenance, binary trust, update metadata, and policy bundles;
- expose crisp questions to other services, such as `is this extractor trusted for this MIME type?`, `is this binary from a trusted profile?`, and `is this update signed for this channel?`;
- emit trust receipts.

Must not:

- scan arbitrary user content as part of normal analytics;
- call cloud services unless the relevant trust policy explicitly requires it;
- become a generic filesystem crawler.

### `sourceos-healthd`

Responsibilities:

- observe systemd units, cgroups, PSI pressure, memory, CPU, IO, thermal, battery, journal rates, queue depth, and daemon budget status;
- enforce state transitions for service health: `healthy`, `constrained`, `paused`, `degraded`, `quarantined`, `requires-attention`;
- surface unknown actor/origin defects;
- feed `sourceos status`, `doctor.sh`, and future UI panels.

Must not:

- stream unbounded logs into the UI;
- query every file to diagnose indexing;
- perform content extraction;
- send remote analytics by default.

### `sourceos-receiptd`

Responsibilities:

- collect compact receipts from index, trust, volume, sync, backup, update, and diagnostic paths;
- store local-first evidence in a queryable ledger;
- sign promoted receipts when required;
- redact sensitive fields according to policy;
- expose receipts to `agentplane`, `sociosphere`, `prophet-cli`, and `contractforge` once canonical schemas exist.

Must not:

- create hidden telemetry channels;
- preserve sensitive full content by default;
- conflate local receipts with remote analytics.

## Canonical event shape

The minimal event shape is:

```json
{
  "schema": "sourceos.index.event.v0",
  "event_id": "01HX...",
  "observed_at": "2026-05-05T00:00:00Z",
  "actor": {
    "uid": 1000,
    "process": "bearbrowser",
    "systemd_unit": "app-flatpak-dev.sourceos.BearBrowser.scope",
    "sandbox": "flatpak|podman|toolbox|host|unknown",
    "trust_ref": "sigstore|rpm-ostree|flatpak|oci|unknown"
  },
  "object": {
    "path": "/home/user/Documents/example.pdf",
    "volume_id": "sourceos-volume-documents",
    "inode": "optional",
    "content_hash": "blake3:...",
    "mime": "application/pdf"
  },
  "operation": "create|modify|delete|rename|metadata_update|sync_pull|sync_push",
  "policy": {
    "indexing": "allowed|metadata_only|denied",
    "cloud": "none|local_only|sync_allowed|backup_allowed",
    "privacy": "public|private|sensitive|secret"
  },
  "receipt": {
    "extractor": "pdf-text-extractor@0.1.0",
    "status": "indexed|skipped|failed|quarantined",
    "reason": "ok|policy_denied|budget_exceeded|parse_error|unknown_actor"
  }
}
```

## Resource budget model

Every service must run under an explicit systemd slice and cgroup budget.

| Slice | Purpose | Default posture |
|---|---|---|
| `sourceos-index.slice` | index orchestration and queueing | low CPU weight, IO throttled, battery aware |
| `sourceos-extract.slice` | sandboxed extraction workers | per-file timeout, memory cap, MIME quota |
| `sourceos-health.slice` | observation and reporting | read-mostly, no broad traversal |
| `sourceos-sync.slice` | sync and backup clients | explicit network policy and signed intent |
| `sourceos-ui.slice` | user-facing status/search panels | interactive priority, bounded log fetch |

Budget violations must transition state, not merely log. Required behavior:

- first violation: emit warning receipt and reduce concurrency;
- repeated violation: pause offending MIME extractor, path, or actor lane;
- severe violation: quarantine extractor or daemon lane;
- unknown actor plus high resource use: mark degraded and require attention;
- low disk or memory pressure: switch to metadata-only or pause compaction.

## Volume and path policy

Default policies:

| Path / volume | Default indexing | Default semantic embedding | Default cloud exposure |
|---|---|---|---|
| Documents | full text when local | opt-in | none unless signed sync/backup intent |
| Downloads | metadata-only plus trust/malware hooks | off | none |
| Desktop | metadata + text for safe types | opt-in | none |
| Music | metadata-only | off | none |
| Videos | metadata-only | off | none |
| Pictures | metadata-only, image labels opt-in | off | none |
| Source code workspaces | text index, secret-aware exclusions | opt-in | none |
| Cloud mounts | metadata-only unless volume policy says otherwise | off | governed by sync policy |
| Removable drives | metadata-only until trusted | off | none |
| Secrets/key stores | denied | denied | denied |

Downloads are intentionally conservative. SourceOS should not deeply parse arbitrary new files before trust and user intent are known.

## CLI surface

Required first CLI commands:

```bash
sourceos index status
sourceos index explain --file ~/Documents/example.pdf
sourceos index pause --mime application/pdf --duration 30m
sourceos index policy set ~/Downloads --mode metadata-only
sourceos health top --slice sourceos-index.slice
sourceos receipts query --actor sourceos-indexd --since 24h
sourceos trust explain --path /usr/bin/example
```

Required JSON/report integration:

- `sourceos status --json` includes index and health warnings without breaking existing shape;
- `doctor.sh --json` includes index queue, extractor, receipt, trust, and volume-policy warnings;
- report schemas are later canonized in `SourceOS-Linux/sourceos-spec`.

## UI surface

A future Knowledge & Indexing panel should expose:

- current queue depth;
- files pending, indexed, skipped, failed, quarantined;
- per-volume policy;
- per-MIME policy;
- extractor health;
- semantic embedding policy;
- cloud exposure policy;
- recent receipts;
- high CPU / IO / memory budget findings;
- result explanation for search hits;
- kill switches for full-text indexing, semantic indexing, cloud indexing, and all background indexing.

## Search as evidence fabric

Every indexed object becomes part of a governed knowledge graph:

| Node / edge | Meaning |
|---|---|
| File node | path, content hash, volume, owner, policy |
| Text span | stable span ID, byte/character offsets, extractor version |
| Semantic chunk | embedding model ID, local/remote flag, consent receipt |
| Entity node | people, projects, organizations, topics, equations, citations |
| Provenance edge | `derived_from`, `mentions`, `cites`, `opened_by`, `edited_by`, `synced_by` |
| Policy edge | `allowed_for_index`, `metadata_only`, `denied_for_cloud`, `requires_unlock` |

This gives SourceOS a stronger claim than ordinary desktop search: not just findability, but explainable, policy-bound, provenance-backed retrieval.

## Acceptance tests

A first implementation slice is acceptable when:

1. `sourceos index status --json` returns queue depth, index generation, failed extractors, paused lanes, and budget state.
2. `sourceos index explain --file <path>` returns last event, policy basis, extractor, receipt status, and index generations.
3. `sourceos index policy set ~/Downloads --mode metadata-only` prevents full-text extraction for new Downloads files.
4. A synthetic bad extractor exceeding CPU or memory is paused and emits a budget violation receipt.
5. A cloud-mounted folder defaults to metadata-only unless explicit policy enables more.
6. `doctor.sh --json` can report unknown actor, high queue depth, failed extractor, and paused lane states.
7. Search result explanations include path, span ID or metadata source, extractor version, and privacy policy.
8. No daemon sends remote analytics or remote inference events in default mode.
9. Diagnostics tools demonstrate bounded log retrieval and do not trigger sustained high resource use.
10. All new report shapes have sample fixtures ready to be canonized in `sourceos-spec`.

## Implementation backlog

### P0 — contracts and scaffolding

- Add this ADR and align it with the workstation parity plan.
- Define first `sourceos.index.event.v0`, `sourceos.index.receipt.v0`, and `sourceos.health.daemon_budget.v0` example shapes.
- Add `sourceos index status` and `sourceos index explain` placeholders or documented stubs.
- Add doctor/status warning placeholders without breaking existing JSON shape.

### P1 — local event and policy spine

- Implement event ledger prototype.
- Implement volume/path policy loading.
- Add metadata-only policy for Downloads and removable media.
- Add extractor dispatch contract.

### P2 — extractor sandbox and budget enforcement

- Run extractors under `sourceos-extract.slice`.
- Add timeout, memory cap, file-size cap, MIME quota, and crash quarantine.
- Emit receipts for all extractor outcomes.

### P3 — materialized search indexes

- Add lexical indexing with Tantivy or Xapian.
- Add metadata store.
- Add optional vector and graph materializers behind explicit policy.

### P4 — UI and agent ingestion

- Add Knowledge & Indexing panel.
- Canonize report schemas in `sourceos-spec`.
- Expose receipts to `agentplane`, `sociosphere`, `prophet-cli`, and `contractforge`.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Indexer becomes a privileged crawler | privacy and security collapse | event/policy split, sandboxed extractors, receipts |
| Diagnostics generate load | degraded UX | observer budgets, bounded sampling, no unbounded log reflection |
| Search implies cloud exposure | trust collapse | signed intent, volume policy, local-first default |
| Semantic embeddings leak sensitive data | privacy collapse | opt-in per path/type, local models default, receipt every embedding |
| Unknown actor state is normalized | weak forensic value | unknown is degraded state and doctor warning |
| One daemon accumulates duties | macOS-style coupling | one-daemon-one-job rule and cross-service contract review |

## Claim discipline

Permitted after this ADR lands:

- SourceOS has an explicit architecture for local search, diagnostics, and evidence receipts.
- SourceOS is designing against known daemon-coupling failure patterns in proprietary desktop OSes.
- SourceOS treats indexing, diagnostics, trust, health, and receipts as separate planes.

Not permitted yet:

- production-grade local search;
- full Spotlight replacement;
- full macOS parity;
- complete privacy/trust envelope;
- complete semantic knowledge graph.

## Immediate next actions

1. Create implementation issues for `sourceos-indexd`, `sourceos-healthd`, `sourceos-receiptd`, extractor sandboxing, and the Knowledge & Indexing UI.
2. Add minimal JSON fixtures and status/doctor warning stubs in a follow-up implementation PR.
3. Cross-link with `SourceOS-Linux/sourceos-spec` once report schemas are canonized.
