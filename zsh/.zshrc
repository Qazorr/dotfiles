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

# Debian renames these two to avoid clashing with older packages (fd-find ->
# fdfind, bat -> batcat). Alias them back to the names everything documents.
command -v fdfind >/dev/null && alias fd='fdfind'
command -v batcat >/dev/null && alias bat='batcat'
command -v eza    >/dev/null && alias ll='eza -lah --group-directories-first --icons'
command -v btop   >/dev/null && alias top='btop'

# Keyboard shortcut cheat sheet, same thing SUPER+SHIFT+/ opens.
alias keys='keybind-help'

# --- Editor ---
# EDITOR stays terminal-native (git commit messages, etc.) even though VS
# Code is the primary editor — GUI editors are a bad default for $EDITOR.
export EDITOR=vi
command -v code >/dev/null && export VISUAL='code --wait'

# zoxide: smarter `cd` that learns your most-used directories (`z <fragment>`)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# --- Dev environment ---
# direnv: per-project env vars (Python venvs, Node versions, etc.) — install
# with `sudo apt install direnv` if you want this, it's optional.
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# cargo, if you installed a Rust toolchain (no longer needed by these
# dotfiles — DMS ships prebuilt binaries).
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Local scripts (monitor-switch, etc.) + DMS binaries. Login shells already
# get these from .zprofile; this covers non-login interactive shells.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/bin:$PATH"

# --- System info banner on new terminals ---
command -v fastfetch >/dev/null && fastfetch
