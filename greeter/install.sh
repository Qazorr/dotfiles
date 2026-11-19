#!/usr/bin/env bash
# greeter/install.sh USER — as root: applies patches/ to the installed
# dms-greeter's built-in UI. A patch that doesn't apply fails the run and keeps
# the last good build.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${1:?usage: greeter/install.sh USER}"
DEST=/usr/local/share/dotfiles/greeter-shell

version="$(/usr/bin/dms-greeter version | awk '{print $2}')"
patches="$(cat "$SRC"/patches/*.patch | sha256sum | cut -d' ' -f1)"
if [ "$(cat "$DEST/VERSION" 2>/dev/null)" = "$version" ] \
    && [ "$(cat "$DEST/PATCHES" 2>/dev/null)" = "$patches" ]; then
    echo "greeter UI unchanged"
    exit 0
fi

tmp="$(mktemp -d)"
# The unpacked UI is read-only.
trap 'chmod -R u+w "$tmp"; rm -rf "$tmp"' EXIT
chmod 711 "$tmp"
install -d -m700 -o "$USER_NAME" "$tmp/run" "$tmp/home"

# dms-greeter unpacks its UI into $XDG_RUNTIME_DIR before launching it; with no
# display it then exits.
timeout -k 5 30 runuser -u "$USER_NAME" -- env -i PATH=/usr/bin:/bin \
    HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run" LANG=C.UTF-8 QT_QPA_PLATFORM=offscreen \
    /usr/bin/dms-greeter run >"$tmp/log" 2>&1 || true
ui="$(compgen -G "$tmp/run/dms-greeter-shell/*/shell.qml" | head -1 || true)"
[ -n "$ui" ] || {
    echo "dms-greeter $version didn't unpack its UI:" >&2
    cat "$tmp/log" >&2
    exit 1
}

cp -r "$(dirname "$ui")" "$tmp/ui"
chmod -R u+w "$tmp/ui"
for p in "$SRC"/patches/*.patch; do
    git -C "$tmp/ui" apply "$p" || {
        echo "$(basename "$p") no longer applies to dms-greeter $version — redo it against the new UI" >&2
        exit 1
    }
done
echo "$version" >"$tmp/ui/VERSION"
echo "$patches" >"$tmp/ui/PATCHES"
chmod -R a+rX "$tmp/ui"

install -d "${DEST%/*}"
rm -rf "$DEST.new"
cp -r "$tmp/ui" "$DEST.new"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"
echo "greeter UI built for dms-greeter $version"
