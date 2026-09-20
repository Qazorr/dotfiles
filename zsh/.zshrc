HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
# syntax-highlighting has to stay last: it wraps every other widget, so
# anything after it is ignored. oh-my-zsh is installed with --keep-zshrc, so
# it never rewrites this file.
plugins=(git sudo colored-man-pages docker fzf extract command-not-found
         zsh-autosuggestions zsh-syntax-highlighting)
[ -d "$ZSH" ] && source "$ZSH/oh-my-zsh.sh"

alias ls='ls --color=auto'
alias ll='ls -lah'
# VS Code needs the flag to run natively on Wayland instead of XWayland.
alias code='code --ozone-platform=wayland --enable-features=WaylandWindowDecorations'

# Debian renames these (fd-find -> fdfind, bat -> batcat).
command -v fdfind >/dev/null && alias fd='fdfind'
command -v batcat >/dev/null && alias bat='batcat'
command -v eza    >/dev/null && alias ll='eza -lah --group-directories-first --icons'
command -v btop   >/dev/null && alias top='btop'

alias keys='keybind-help'

export EDITOR=vi
command -v code >/dev/null && export VISUAL='code --wait'

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

command -v direnv >/dev/null && eval "$(direnv hook zsh)"

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Login shells get this from .zprofile; this covers non-login ones.
# Keep in sync with lib/paths.sh — ./bootstrap.sh --doctor checks.
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/uv/bin:$HOME/.local/share/krk-commute/bin:$HOME/.local/bin:$PATH"

command -v fastfetch >/dev/null && fastfetch
