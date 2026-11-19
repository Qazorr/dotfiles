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

# Transfers started from a terminal get rsync_progress's panel. Skipped when the
# output is wanted as rsync prints it: dry runs, itemized lists, --stats, your
# own progress options, quiet, help, or a pipe/file on stdout. `command rsync`
# always bypasses it.
rsync() {
	local a skip=0
	for a in "$@"; do
		case $a in
			--version|--help|-h|--list-only|--daemon|--dry-run|--itemize-changes|--stats|--info=*|--progress|--quiet) skip=1 ;;
			--*) ;;
			-*[niPq]*) skip=1 ;;
		esac
	done
	if [[ -t 1 && $skip == 0 ]] && (( $+commands[rsync_progress] )); then
		setopt local_options pipefail
		command rsync --info=progress2,name1 "$@" | rsync_progress
	else
		command rsync "$@"
	fi
}

# Debian renames these (fd-find -> fdfind, bat -> batcat).
command -v fdfind >/dev/null && alias fd='fdfind'
command -v batcat >/dev/null && alias bat='batcat'
command -v eza >/dev/null && alias ll='eza -lah --group-directories-first --icons'
command -v btop >/dev/null && alias top='btop'

export EDITOR=vi
command -v code >/dev/null && export VISUAL='code --wait'

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

command -v direnv >/dev/null && eval "$(direnv hook zsh)"

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Login shells get this from .zprofile; this covers non-login ones.
# Keep in sync with lib/paths.sh.
typeset -U path
export PATH="$HOME/.local/share/dms/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
	export REQUESTS_CA_BUNDLE=$SSL_CERT_FILE
	export NODE_EXTRA_CA_CERTS=$SSL_CERT_FILE
	export GIT_SSL_CAINFO=$SSL_CERT_FILE
fi

# Anything personal or per-machine: proxies, tokens, work aliases.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
