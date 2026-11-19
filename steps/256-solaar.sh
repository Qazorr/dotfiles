register_step solaar \
    --desc "Solaar, for Logitech Unifying/Bolt receivers (opt-in: ./bootstrap.sh solaar)" \
    --group apps --root --optional --needs prereqs \
    --provides solaar

step_solaar() {
    log "Installing Solaar"
    apt_install solaar
}
