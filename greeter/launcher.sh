#!/bin/sh
# greetd's command: the patched UI only while it matches the installed dms-greeter.
export FONTCONFIG_FILE=@FONTS@
shell=@SHELL_DIR@
if [ "$(cat "$shell/VERSION" 2>/dev/null)" = "$(/usr/bin/dms-greeter version 2>/dev/null | awk '{print $2}')" ]; then
    exec /usr/bin/dms-greeter --shell-dir "$shell" -C @HYPR@ "$@"
fi
exec /usr/bin/dms-greeter -C @HYPR@ "$@"
