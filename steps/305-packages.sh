register_step packages \
    --desc "Everything in packages.list — apt packages added by hand since the install" \
    --group core --root --always

step_packages() {
    local missing=()
    mapfile -t missing < <(packages_missing)
    if [ ${#missing[@]} -gt 0 ]; then
        log "Installing from packages.list: ${missing[*]}"
        apt_install "${missing[@]}"
    fi
    packages_baseline_init
}
