# Podman / OCI local control node

This note captures the first operator-host follow-on for the workstation-v0 stack.

The workstation profile is also the first local control node for:
- local OCI image builds
- local Node Commander runtime staging
- pre-promotion validation work

Current assumptions:
- container runtime: Podman
- packaging target: OCI image
- first runtime: node-commander

Expected host paths:
- /etc/node-commander
- /var/lib/node-commander
- /var/lib/node-commander/evidence
