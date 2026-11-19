PLASMA_EXT_ID=cimiefiiaegbelhefglklhhakcgmhkai

register_step plasmabrowser \
    --desc "Plasma Browser Integration: full-res MPRIS artwork from Brave for DMS" \
    --group apps --root --needs brave \
    --provides /usr/bin/plasma-browser-integration-host

step_plasmabrowser() {
    log "Installing plasma-browser-integration"
    apt_install plasma-browser-integration kimageformat6-plugins

    local hosts="$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    mkdir -p "$hosts"
    cp /usr/share/plasma-browser-integration/org.kde.plasma.chrome_browser_integration.json \
        "$hosts/org.kde.plasma.browser_integration.json"

    sudo mkdir -p /etc/brave/policies/managed
    sudo tee /etc/brave/policies/managed/plasma-integration.json >/dev/null <<EOF
{
  "ExtensionSettings": {
    "$PLASMA_EXT_ID": {
      "installation_mode": "normal_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  }
}
EOF
}
