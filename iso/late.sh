#!/bin/sh
# Runs in-target at the end of the install (preseed/late_command). POSIX sh,
# and a script rather than an inline one-liner so it can be read, tested and
# linted — and so a failed clone says so instead of leaving an motd
# pointing at a ~/dotfiles that was never created.
set -u

REPO_HTTPS=https://github.com/Qazorr/dotfiles.git
REPO_SSH=git@github.com:Qazorr/dotfiles.git

user="$(getent passwd 1000 | cut -d: -f1)"
home="/home/$user"

if git clone "$REPO_HTTPS" "$home/dotfiles"; then
    # HTTPS to clone (no credentials needed), SSH afterwards so pushing works
    # once a key is on the machine.
    git -C "$home/dotfiles" remote set-url origin "$REPO_SSH"
    chown -R "$user:$user" "$home/dotfiles"
    cat > /etc/motd <<EOF

This machine was installed from the dotfiles ISO.
Run:  cd ~/dotfiles && ./bootstrap.sh

EOF
else
    cat > /etc/motd <<EOF

This machine was installed from the dotfiles ISO, but cloning the repo
failed (see /var/log/installer/syslog). Once you have network:

  git clone $REPO_HTTPS ~/dotfiles
  cd ~/dotfiles && ./bootstrap.sh

EOF
fi
