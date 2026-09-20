# shellcheck shell=bash
register_step nala \
    --desc "nala, plus an apt shim in /usr/local/bin that hands it apt's everyday verbs" \
    --group shell --root \
    --provides nala /usr/local/bin/apt

step_nala() {
    ensure_nala

    log "Installing the apt → nala shim at /usr/local/bin/apt"
    sudo tee /usr/local/bin/apt >/dev/null <<'EOF'
#!/bin/sh
# Managed by ~/dotfiles (setup/steps/nala.sh). Anything nala can't take the
# same way — no terminal, an unshared verb or flag — goes to /usr/bin/apt.
real=/usr/bin/apt
if [ ! -x /usr/bin/nala ] || [ ! -t 1 ]; then
    exec "$real" "$@"
fi

case "$1" in
    install|remove|purge|autoremove|autopurge|update|upgrade|full-upgrade|\
    search|show|list|clean) ;;
    *) exec "$real" "$@" ;;
esac

for arg in "$@"; do
    case "$arg" in
        -*) ;;
        *) continue ;;
    esac
    case "$arg" in
        -y|--assume-yes|-t|--target-release|--target-release=*|-o|--option|\
        --option=*|-d|--download-only|-f|--fix-broken|--purge|--autoremove|\
        -a|--all-versions|--installed|--upgradable|--full|-h|--help) ;;
        *) exec "$real" "$@" ;;
    esac
done

exec /usr/bin/nala "$@"
EOF
    sudo chmod 755 /usr/local/bin/apt

    [ "$(sudo sh -c 'command -v apt')" = /usr/local/bin/apt ] \
        || warn "sudo's secure_path doesn't put /usr/local/bin first — \`sudo apt\` will still reach plain apt"
}
