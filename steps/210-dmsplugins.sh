# Plugins installed from their own repos, pinned in dms-plugins.lock.json.
# After installing or updating one: dms plugins lock -o ~/dotfiles/dms-plugins.lock.json
DMS_PLUGINS_LOCK="$REPO/dms-plugins.lock.json"
mapfile -t DMS_PLUGINS < <(sed -n 's/^    "\([A-Za-z0-9_-]*\)": {$/\1/p' "$DMS_PLUGINS_LOCK")

register_step dmsplugins \
    --desc "DMS plugins pinned in dms-plugins.lock.json: ${DMS_PLUGINS[*]}" \
    --group desktop --needs prereqs dms \
    --provides "${DMS_PLUGINS[@]/#/$HOME/.config/dms/plugins/}"

step_dmsplugins() {
    local p
    log "Restoring the DMS plugins pinned in dms-plugins.lock.json"
    dms plugins restore "$DMS_PLUGINS_LOCK"
    for p in "${DMS_PLUGINS[@]}"; do
        dms_enable_plugin "$p"
    done
}
