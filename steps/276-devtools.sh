LAZYGIT_VERSION=0.64.1
LAZYDOCKER_VERSION=0.25.2
GH_VERSION=2.104.0
GLAB_VERSION=1.130.0
HURL_VERSION=8.0.1
SHFMT_VERSION=3.14.1
GO_VERSION=1.27.4

register_step devtools \
    --desc "mise-managed dev tools: lazygit, lazydocker, gh, glab, hurl, shfmt, Go" \
    --group dev --root --needs web \
    --provides lazygit lazydocker gh glab hurl shfmt go

step_devtools() {
    log "Installing dev tools with mise"
    mise use --global \
        lazygit@$LAZYGIT_VERSION lazydocker@$LAZYDOCKER_VERSION \
        gh@$GH_VERSION glab@$GLAB_VERSION hurl@$HURL_VERSION \
        shfmt@$SHFMT_VERSION go@$GO_VERSION
}
