register_step precommit \
    --desc "pre-commit, with this repo's hook (the CI checks, run on commit)" \
    --group dev --root --needs prereqs \
    --provides pre-commit "$REPO/.git/hooks/pre-commit"

step_precommit() {
    log "Installing pre-commit"
    apt_install pre-commit
    log "Installing the pre-commit hook in $REPO"
    ( cd "$REPO" && pre-commit install )
}
