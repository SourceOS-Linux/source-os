# SourceOS Workstation v0 shell spine (fish)
# Safe to source multiple times.

if set -q SOURCEOS_SHELL_SPINE_LOADED
  exit 0
end
set -gx SOURCEOS_SHELL_SPINE_LOADED 1

# Ensure ~/.local/bin is on PATH (fish-native)
if type -q fish_add_path
  fish_add_path -m $HOME/.local/bin
else
  set -gx PATH $HOME/.local/bin $PATH
end

# direnv
if type -q direnv
  direnv hook fish | source
end

# atuin
if type -q atuin
  atuin init fish --disable-up-arrow | source
end

# zoxide
if type -q zoxide
  zoxide init fish | source
  alias cd z
end

# ergonomic aliases
if type -q eza
  alias ls 'eza --group-directories-first --icons'
  alias ll 'eza -lah --group-directories-first --icons'
end

if type -q bat
  alias cat bat
end

if type -q yazi
  alias y yazi
end
