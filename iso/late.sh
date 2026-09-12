#!/bin/sh
# Runs in-target at the end of the install (preseed/late_command). POSIX sh,
# and a script rather than an inline one-liner so it can be read, tested and
# linted — and so a half-done setup says so instead of leaving an motd that
# points at a ~/dotfiles which was never created.
set -u

REPO_HTTPS=https://github.com/Qazorr/dotfiles.git
REPO_SSH=git@github.com:Qazorr/dotfiles.git

# Every step, not just the clone: a root-owned ~/dotfiles is half-done too.
setup_repo() {
    [ -n "$user" ] || return 1
    git clone "$REPO_HTTPS" "$home/dotfiles" || return 1
    # HTTPS to clone (no credentials needed), SSH after, so pushing works
    # once a key is on the machine.
    git -C "$home/dotfiles" remote set-url origin "$REPO_SSH" || return 1
    chown -R "$user:$user" "$home/dotfiles" || return 1
}

user="$(getent passwd 1000 | cut -d: -f1)"
home="/home/$user"

if setup_repo; then
    cat > /etc/motd <<EOF

This machine was installed from the dotfiles ISO.
Run:  cd ~/dotfiles && ./bootstrap.sh

EOF
else
    cat > /etc/motd <<EOF

This machine was installed from the dotfiles ISO, but setting up the repo
failed (see /var/log/installer/syslog). Once you have network:

  git clone $REPO_HTTPS ~/dotfiles
  cd ~/dotfiles && ./bootstrap.sh

EOF
fi
