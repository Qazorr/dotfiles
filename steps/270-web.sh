BRUNO_VERSION=4.2.1
BRUNO_SHA256=7c36f0d7f15899bb48ab298d362da2741edc392c702faf13dd96ee12afd47a88
HURL_VERSION=8.0.1
HURL_SHA256=e76e6c0957f83f9b761416452871554d0f068384b6cd004bff82dd8795c62225

register_step web \
    --desc "Web dev: Bruno, hurl, mise + Node LTS, mkcert, pgcli, litecli" \
    --group dev --root --needs prereqs \
    --provides bruno hurl mise mkcert pgcli litecli "$HOME/.local/share/mise/shims/node"

_web_deb() {   # _web_deb <package> <version> <url> <sha256>
    if [ "$(dpkg-query -W -f='${Version}' "$1" 2>/dev/null)" = "$2" ]; then
        log "$1 $2 already installed, skipping"
        return 0
    fi
    log "Installing $1 $2"
    apt_install_deb "$3" "$4"
}

step_web() {
    _web_deb bruno "$BRUNO_VERSION" \
        "https://github.com/usebruno/bruno/releases/download/v$BRUNO_VERSION/bruno_${BRUNO_VERSION}_amd64_linux.deb" \
        "$BRUNO_SHA256"
    _web_deb hurl "$HURL_VERSION" \
        "https://github.com/Orange-OpenSource/hurl/releases/download/$HURL_VERSION/hurl_${HURL_VERSION}_amd64.deb" \
        "$HURL_SHA256"

    log "Ensuring mise's apt repo is set up"
    ensure_apt_key https://mise.jdx.dev/gpg-key.pub /usr/share/keyrings/mise-archive-keyring.gpg dearmor
    ensure_apt_list /etc/apt/sources.list.d/mise.list \
        "deb [signed-by=/usr/share/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
        "mise.jdx.dev/deb"

    log "Installing mise, mkcert, pgcli, litecli"
    apt_install mise mkcert libnss3-tools pgcli litecli

    log "Installing Node LTS as the global default"
    mise use --global node@lts
}
