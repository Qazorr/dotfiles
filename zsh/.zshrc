# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# --- oh-my-zsh ---
# Installed by bootstrap.sh (unattended, --keep-zshrc so it never touches
# this file). Handles completion/compinit, emacs-style keybinds, and the
# prompt itself — no need to hand-roll those separately.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git sudo colored-man-pages)
[ -d "$ZSH" ] && source "$ZSH/oh-my-zsh.sh"

# --- Aliases ---
alias ls='ls --color=auto'
alias ll='ls -lah'
# VS Code needs an explicit flag to run natively on Wayland instead of XWayland
alias code='code --ozone-platform=wayland --enable-features=WaylandWindowDecorations'

# --- Editor ---
# EDITOR stays terminal-native (git commit messages, etc.) even though VS
# Code is the primary editor — GUI editors are a bad default for $EDITOR.
export EDITOR=vi
command -v code >/dev/null && export VISUAL='code --wait'

# --- Dev environment ---
# direnv: per-project env vars (Python venvs, Node versions, etc.) — install
# with `sudo apt install direnv` if you want this, it's optional.
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# cargo (installed by bootstrap.sh, used for swww/wallust)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Local scripts (monitor-switch, wallust-apply, etc.)
export PATH="$HOME/.local/bin:$PATH"

# --- System info banner on new terminals ---
command -v fastfetch >/dev/null && fastfetch
