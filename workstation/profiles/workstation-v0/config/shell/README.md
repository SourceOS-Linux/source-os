# Shell spine (Workstation Profile v0)

This directory contains the **keyboard-first shell UX spine** for the workstation profile.

Design goals:

- Predictable navigation primitives (fzf, zoxide, atuin)
- XDG-friendly configuration (avoid scattering files)
- Minimal invasive changes to user dotfiles (provide a single snippet to source)
- Works in zsh, bash, and fish (where possible)

## Files

- `common.sh`: shared functions + env
- `zshrc.snippet`: zsh-specific glue
- `bashrc.snippet`: bash-specific glue

## How to enable

The profile installer will:

1) Create `~/.config/sourceos/` and copy these files.
2) Append a single guarded `source` line into the user’s shell rc (opt-in behavior is preferred; v0 prints instructions and does not mutate by default).

Until we implement the dotfile mutator, you can enable manually by sourcing the snippet.
