#!/usr/bin/env bash
# Common shell spine for SourceOS Workstation Profile v0
# Safe to source multiple times.

if [[ -n "${SOURCEOS_SHELL_SPINE_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
export SOURCEOS_SHELL_SPINE_LOADED=1

# --- direnv ---
if command -v direnv >/dev/null 2>&1; then
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    eval "$(direnv hook zsh)"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    eval "$(direnv hook bash)"
  fi
fi

# --- atuin ---
if command -v atuin >/dev/null 2>&1; then
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    eval "$(atuin init zsh --disable-up-arrow)"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    eval "$(atuin init bash --disable-up-arrow)"
  fi
fi

# --- zoxide ---
if command -v zoxide >/dev/null 2>&1; then
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    eval "$(zoxide init zsh)"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    eval "$(zoxide init bash)"
  fi
  alias cd='z' 2>/dev/null || true
fi

# --- fzf defaults (fd-backed) ---
if command -v fzf >/dev/null 2>&1; then
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
fi

# --- ergonomic aliases ---
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons' 2>/dev/null || true
  alias ll='eza -lah --group-directories-first --icons' 2>/dev/null || true
fi
if command -v bat >/dev/null 2>&1; then
  alias cat='bat' 2>/dev/null || true
fi
if command -v yazi >/dev/null 2>&1; then
  alias y='yazi' 2>/dev/null || true
fi

# --- clipboard abstraction ---
clipcopy() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  else
    echo "No clipboard tool found (pbcopy/wl-copy/xclip)" >&2
    return 1
  fi
}

clippaste() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v wl-paste >/dev/null 2>&1; then
    wl-paste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  else
    echo "No clipboard tool found (pbpaste/wl-paste/xclip)" >&2
    return 1
  fi
}
