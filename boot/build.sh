#!/usr/bin/env bash
# boot/build.sh OUT — renders the GRUB and Plymouth themes into OUT/grub and
# OUT/plymouth. No root needed; the grub step and boot/preview install from here.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:?usage: boot/build.sh OUT}"
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans

# No timestamps in the PNGs, so an unchanged palette builds identical files
# and boot/install.sh can skip the initramfs rebuild.
magick() { command magick "${@:1:$#-1}" -define png:exclude-chunks=date,time "${@: -1}"; }
LOGO=/usr/share/icons/desktop-base/scalable/emblems/emblem-debian-white.svg

# DMS's palette, generated from the wallpaper; blue-grey without DMS.
eval "$(python3 - "$HOME/.cache/dms/dms-colors.json" <<'PY'
import json, sys
pal = dict(BG="#0e0f14", FG="#e6e7ef", SUB="#a3a5b2", MUTED="#80828f",
           ACCENT="#a8c7fa", TRACK="#2a2c36")
try:
    c = json.load(open(sys.argv[1]))["colors"]["dark"]
    pal.update(BG=c["background"], FG=c["on_surface"], SUB=c["on_surface_variant"],
               MUTED=c["outline"], ACCENT=c["primary"], TRACK=c["surface_container_high"])
except (OSError, KeyError, ValueError):
    pass
for k, v in pal.items():
    rgb = ", ".join("%.3f" % (int(v[i:i + 2], 16) / 255) for i in (1, 3, 5))
    print(f'{k}="{v}"; {k}_RGB="{rgb}"')
PY
)"

# The DMS wallpaper, so boot leads into the login screen; a flat colour without one.
wallpaper() {
    local path
    path="$(sed -n 's/.*"wallpaperPath": *"\([^"]*\)".*/\1/p' \
        "$HOME/.local/state/dms/session.json" \
        "$HOME/.local/state/DankMaterialShell/session.json" 2>/dev/null | head -1)"
    [ -f "$path" ] && printf '%s' "$path"
}

backdrop() {
    local src; src="$(wallpaper || true)"
    if [ -n "$src" ]; then
        magick "$src[0]" -resize 1920x1080^ -gravity center -extent 1920x1080 \
            -blur 0x24 -fill "$BG" -colorize 50% -depth 8 "PNG24:$1"
    else
        magick -size 1920x1080 "xc:$BG" -depth 8 "PNG24:$1"
    fi
}

# 9-slice rounded pill for the selected menu entry; the others get a clear one
# of the same size, or GRUB spaces the selected entry further apart.
pill() {
    local out="$1" name="$2" fill="$3" stroke="$4" r=10 s=40 m=20
    magick -size ${s}x${s} xc:none -fill "$fill" -stroke "$stroke" -strokewidth 1 \
        -draw "roundrectangle 0.5,0.5 $((s - 1)).5,$((s - 1)).5 $r,$r" "PNG32:$out/pill.png"
    local part geo
    for part in nw:${r}x${r}+0+0 n:${m}x${r}+${r}+0 ne:${r}x${r}+$((r + m))+0 \
                w:${r}x${m}+0+${r} c:${m}x${m}+${r}+${r} e:${r}x${m}+$((r + m))+${r} \
                sw:${r}x${r}+0+$((r + m)) s:${m}x${r}+${r}+$((r + m)) se:${r}x${r}+$((r + m))+$((r + m)); do
        geo="${part#*:}"
        magick "$out/pill.png" -crop "$geo" +repage "PNG32:$out/${name}_${part%%:*}.png"
    done
    rm "$out/pill.png"
}

logo() {
    magick -background none -density 384 "$LOGO" -resize "${2}x${2}" "PNG32:$1"
}

HOST="$(hostname)"
OS="$(. /etc/os-release && echo "${NAME%% *} $VERSION_ID ${VERSION_CODENAME}" | tr 'A-Z' 'a-z')"
fill() {
    local args=(-e "s|@HOST@|$HOST|g" -e "s|@OS@|$OS|g") k rgb
    for k in BG FG SUB MUTED ACCENT; do
        rgb="${k}_RGB"
        args+=(-e "s|@${k}_RGB@|${!rgb}|g" -e "s|@$k@|${!k}|g")
    done
    sed "${args[@]}" "$1" > "$2"
}

mkdir -p "$OUT/grub" "$OUT/plymouth"

fill "$SRC/grub/theme.txt" "$OUT/grub/theme.txt"
backdrop "$OUT/grub/background.png"
logo "$OUT/grub/logo.png" 72
pill "$OUT/grub" select "${ACCENT}2e" "${ACCENT}55"
pill "$OUT/grub" item none none
grub-mkfont -s 18 -o "$OUT/grub/regular18.pf2" "$FONT.ttf"
grub-mkfont -s 14 -o "$OUT/grub/regular14.pf2" "$FONT.ttf"
grub-mkfont -s 16 -o "$OUT/grub/mono16.pf2" "${FONT}Mono.ttf"

cp "$SRC/plymouth/dotfiles.plymouth" "$OUT/plymouth/"
fill "$SRC/plymouth/dotfiles.script" "$OUT/plymouth/dotfiles.script"
cp "$OUT/grub/background.png" "$OUT/plymouth/background.png"
logo "$OUT/plymouth/logo.png" 88
magick -size 200x2 "xc:$TRACK" "PNG32:$OUT/plymouth/track.png"
magick -size 200x2 "xc:$ACCENT" "PNG32:$OUT/plymouth/bar.png"
