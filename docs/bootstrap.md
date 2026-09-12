# bootstrap.sh
How the installer works, and how to extend it. See the [README](../README.md) to just install.

## Adding or changing a step


Each stage is one self-describing file under `setup/steps/`:

```bash
# setup/steps/docker.sh
register_step docker \
    --desc "Docker Engine + Compose/Buildx plugins, from Docker's own apt repo" \
    --group dev --root --needs prereqs \
    --provides docker

step_docker() {
    ...
}
```

| | |
|---|---|
| `--desc` | what `--list` and the picker print |
| `--group` | which group/profile it belongs to |
| `--root` | it calls `sudo`; decides whether a run asks for a password at all |
| `--always` | never recorded, runs every time (the snapshots, `stow`, `summary`) |
| `--optional` | never auto-selected — not by a plain run, `--profile`, `--group` or `--missing`, only by naming it or ticking it in `--pick`. For a step risky enough that it shouldn't run unattended (`nvidia`) |
| `--needs` | must *already be done* for this step's install to succeed; pulled in automatically. Install-time only, not "would be nice at runtime" |
| `--provides` | a command or path that exists once the step has run. Drives `--list`, `--missing`, `--doctor` |

A step returning 0 without having done its work should call `stamp_skip`, so
it isn't recorded and the next run retries.

A step that needs the user to pick something (which driver, say) declares it
with `register_option`, right in its own file, next to `register_step`:

```bash
register_option nvidia DOTFILES_NVIDIA_MODE \
    --prompt "Which NVIDIA driver?" \
    --choices "debian:..." "open:..." \
    --default debian
```

`resolve_step_options` asks for every registered option once, up front —
before sudo, before anything runs — for whichever of those steps ended up in
the plan. Setting the env var beforehand skips the prompt for that one; see
[NVIDIA](#nvidia--opt-in) for the full picture. Steps read the variable
themselves (`${DOTFILES_NVIDIA_MODE:-debian}`) same as any other override —
`register_option` only drives the prompt, not the step's behavior.

`STEPS` in `bootstrap.sh` is the run order — the one fact that can't live in
a step's own file. `steps_validate()` aborts at startup if the two disagree.

Every step must be **idempotent**; `set -euo pipefail` is on, so guard
anything that can legitimately fail.

### Adding something you just installed

- **An apt package from Debian** — add it to `setup/steps/cli.sh` (shell
  tools) or `desktop.sh` (graphical). Nothing else.
- **A tool with its own apt repo** — a new step using `ensure_apt_key` /
  `ensure_apt_list` / `apt_install`. `docker.sh`, `vscode.sh`, `brave.sh`,
  `danklinux.sh` are worked examples.
- **A single binary from a GitHub release** — a new step using
  `install_github_release_binary` (see `devtools.sh`), pinned to a tag.
- **A dotfile change** — just edit the file; the stowed dirs are symlinks
  into this repo.

**Never install anything into `~/.local/bin`** — it's a stow symlink into
this repo, so anything written there gets committed to git. Use
`/usr/local/bin` (system-wide) or `~/.local/share/<tool>/bin` (per-user, add
it to `DOTFILES_PATH_DIRS` in `lib/paths.sh` and the three files that repeat
that list — `--doctor` checks they agree).

Then `./bootstrap.sh` (editing a step file un-records just that step) and
`./bootstrap.sh --doctor` (catches anything installed by hand that wrote into
the repo behind your back).

Anything that could cost you the machine — a driver, the bootloader, the
login manager — belongs in the VM first (`vm/README.md`).

