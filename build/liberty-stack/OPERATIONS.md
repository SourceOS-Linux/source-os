# Liberty Stack verification operations

This note summarizes the first host lifecycle for the Liberty Stack verification hook in `source-os`.

## Available helpers

- `scripts/install_liberty_stack_verify.sh`
- `scripts/enable_liberty_stack_verify.sh`
- `scripts/status_liberty_stack_verify.sh`
- `scripts/health_liberty_stack_verify.sh`
- `scripts/disable_liberty_stack_verify.sh`

## Suggested first-pass flow

1. install the verification assets
2. review and populate the environment file under `/etc/source-os/liberty-stack`
3. enable the timer-backed verification hook
4. inspect current status and health
5. stop or remove the hook when needed

## Current service artifacts

- `systemd/liberty-stack-verify.service`
- `systemd/liberty-stack-verify.timer`
- `systemd/liberty-stack-verify.preset`

This remains an early substrate slice and should later grow into a fuller host profile and packaging path.
