# --- History ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# --- oh-my-zsh ---
# Installed by bootstrap.sh with --keep-zshrc, so it never touches this file.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
# The last two are separate repos, cloned by bootstrap.sh's ohmyzsh step.
# syntax-highlighting has to stay last: it wraps every other widget, so
# anything after it is ignored.
plugins=(git sudo colored-man-pages docker fzf extract command-not-found
         zsh-autosuggestions zsh-syntax-highlighting)
[ -d "$ZSH" ] && source "$ZSH/oh-my-zsh.sh"

# --- Aliases ---
alias ls='ls --color=auto'
alias ll='ls -lah'
# VS Code needs an explicit flag to run natively on Wayland instead of XWayland
alias code='code --ozone-platform=wayland --enable-features=WaylandWindowDecorations'

# Debian renames these (fd-find -> fdfind, bat -> batcat).
command -v fdfind >/dev/null && alias fd='fdfind'
command -v batcat >/dev/null && alias bat='batcat'
command -v eza    >/dev/null && alias ll='eza -lah --group-directories-first --icons'
command -v btop   >/dev/null && alias top='btop'

# Keyboard shortcut cheat sheet, same thing SUPER+SHIFT+/ opens.
alias keys='keybind-help'

# --- Editor ---
# EDITOR stays terminal-native for git commit messages and the like.
export EDITOR=vi
command -v code >/dev/null && export VISUAL='code --wait'

# zoxide: `z <fragment>` jumps to a directory you use a lot.
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# --- Dev environment ---
# direnv: per-project env vars. Guarded in case the cli step hasn't run.
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# cargo, if a Rust toolchain is installed. Nothing here needs one.
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Login shells get this from .zprofile; this covers non-login ones.
# Keep in sync with lib/paths.sh — ./bootstrap.sh --doctor checks.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/uv/bin:$HOME/.local/share/krk-commute/bin:$HOME/.local/bin:$PATH"

# --- System info banner on new terminals ---
command -v fastfetch >/dev/null && fastfetch
