register_step mediaapps \
    --desc "VLC, Inkscape, OBS Studio" \
    --group apps --root --needs prereqs \
    --provides vlc inkscape obs

step_mediaapps() {
    log "Installing VLC, Inkscape, OBS Studio"
    apt_install vlc inkscape obs-studio
}
