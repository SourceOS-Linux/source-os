# SourceOS Isolation-Space Enforcement

Status: design (implementation follows this doc)
Depends on: `sourceos-spec` `docs/contract-additions/isolation-spaces-and-taints.md`,
`socioprophet-agent-standards` `consent-plane/001-purpose-bound-tool-use-and-agent-roles.md`

## Purpose

The consent-plane defines five isolation **spaces** and admits into them by
**taint ⇄ toleration**; `sourceos-spec` makes that a contract. This doc makes it
**real on the running OS**: it maps each abstract space onto concrete Linux and
existing SourceOS enforcement primitives, so an operation that lacks a toleration
is stopped by the kernel/systemd/eBPF, not merely by policy text.

The org boundary follows the ring: `kernel`/`system` = SourceOS base-OS territory;
`agent`/`user` = SociOS managed/agentic territory.

## Enforcement mapping

| Space | Taint | Enforced by (concrete SourceOS/Linux primitive) |
|---|---|---|
| `agent-space` | — (untainted, native) | Per-agent sandbox: user namespace + seccomp profile + `NoNewPrivileges`; no host mounts beyond the agent workspace. The default home for agent runtimes. |
| `user-space` | `ring=user:PreferNoEntry` | Normal user session (systemd `--user`), standard DAC. Soft cap: entry is recorded in the receipt, never denied. |
| `system-space` | `ring=system:NoEntry` | systemd **system** units with hardening (`ProtectSystem=strict`, `ProtectKernelModules`, `CapabilityBoundingSet=` minimal). Entry requires the `operator` toleration; others are denied by the unit's capability set. |
| `kernel-space` | `ring=kernel:NoEntry` | Privileged operations gated behind the `operator` role only; module load / raw device access blocked for all other roles via `CapabilityBoundingSet` + LSM. |
| `data-namespace` | `tenant=<id>:NoExecute` | Per-tenant **mount + network namespace**; cross-tenant egress denied by the existing eBPF **`ebpf/quarantine/egress_allowlist.bpf.c`**. Withdrawing a tenant toleration flips the allowlist → in-flight cross-tenant flows are cut (Art. 7(3) `NoExecute`). |

## Taint ⇄ toleration → Linux mechanism

- A **toleration** is realized as a capability grant + an eBPF/LSM policy entry
  for the operation's cgroup. For a space carrying a **blocking** taint
  (`NoEntry`/`NoExecute`), no matching toleration ⇒ the syscall is denied
  (fail-closed), not merely logged. A `PreferNoEntry` taint is **non-blocking**
  (see below): it is allowed without a toleration and only recorded.
- **NoEntry**: absent toleration ⇒ blocked by `CapabilityBoundingSet` / LSM.
- **NoExecute**: toleration withdrawal rewrites the eBPF map ⇒ existing flows in
  that `data-namespace` are severed.
- **PreferNoEntry**: allowed; the crossing is written to the Action-Ontology
  receipt for review (soft cap).
- The **surface `space_deny`** is enforced at process launch: a surface agent
  (e.g. BearBrowser) is started in a cgroup whose capability set / eBPF policy
  cannot reach the denied spaces, regardless of its role — so an injected browser
  agent is structurally confined to `agent-space`.

## Implementation plan (follows this design)

1. `modules/nixos/consent-plane-spaces.nix` — a NixOS module exposing
   `sourceos.space.<name>` options that render the systemd hardening +
   capability sets + seccomp per space, and a `sourceos.surface.<id>.spaceDeny`
   that launches a surface's units in the confined cgroup.
2. Extend `ebpf/quarantine` with a per-tenant `data-namespace` allowlist map
   keyed by tenant, wired to consent withdrawal.
3. Receipt emission: every space crossing writes the Action-Ontology receipt
   (`{space, taint, toleration, role, surface, decision}`), the same receipt the
   consent-plane gate records.
4. Conformance: a test that a unit declared for `system-space` without the
   `operator` toleration fails to acquire the capability (denied), and that a
   browser-surface unit cannot open a socket outside its `agent-space` cgroup.

## Non-goals (here)

This is the enforcement design. The NixOS module, the eBPF extension, and the
conformance tests are the follow-on implementation PRs that satisfy it.
