# Upstream Workstreams

## Workstream A — policy and classification MVP
Deliver:
- foreign-volume class model downstream of the merged standards surface
- filesystem policy matrix
- Apple dual-boot posture
- mount-flag defaults and evidence requirements

This is the default and preferred path.

## Workstream B — Linux estate integration
Deliver:
- systemd mount and automount realization where appropriate
- packaging notes and helper placement
- import/export job posture
- rootless and container exposure rules
- later SELinux/AppArmor alignment if needed

## Workstream C — dual-boot and recovery validation
Deliver separately:
- Apple/macOS dual-boot validation notes
- recovery and rollback guidance
- explicit operator flows for safe import and exchange

## Workstream D — explicit read-write exception lane
Defer until the first three workstreams are stable.

This lane should handle only:
- declared exception cases
- evidence-bearing approvals
- tested and documented foreign filesystem write paths

## Rule of thumb

If a foreign volume does not need to be mutated in place, keep the workflow read-only and copy into governed native storage instead.
