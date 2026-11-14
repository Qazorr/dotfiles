VESKTOP_RELEASE=https://github.com/Vencord/Vesktop/releases/latest/download

register_step vesktop \
    --desc "Vesktop (Discord), latest GitHub release .deb (no apt repo)" \
    --group apps --root --needs prereqs \
    --provides vesktop

step_vesktop() {
    local dir manifest version deb sha512
    scratch_dir dir
    manifest=$(curl -fsSL "$VESKTOP_RELEASE/latest-linux.yml") || return 1
    version=$(sed -n 's/^version: *//p' <<<"$manifest")
    deb="vesktop_${version}_amd64.deb"
    sha512=$(awk -v f="$deb" '$1 == "-" && $2 == "url:" { on = ($3 == f) } on && $1 == "sha512:" { print $2; exit }' <<<"$manifest")
    if [ -z "$version" ] || [ -z "$sha512" ]; then
        warn "vesktop: no $deb in latest-linux.yml"
        return 1
    fi

    if [ "$(dpkg-query -W -f='${Version}' vesktop 2>/dev/null)" = "$version" ]; then
        log "Vesktop $version already installed, skipping"
        return 0
    fi
    log "Installing Vesktop $version"
    curl -fsSL -o "$dir/$deb" "$VESKTOP_RELEASE/$deb" || return 1
    [ "$(openssl dgst -sha512 -binary "$dir/$deb" | base64 -w0)" = "$sha512" ] \
        || { warn "$deb: checksum mismatch"; return 1; }
    chmod 755 "$dir"   # apt's _apt user has to read it
    sudo /usr/bin/apt-get install "${APT_OPTS[@]}" "$dir/$deb"
    _apt_record vesktop
}
