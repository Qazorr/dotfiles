#!/usr/bin/env bash
# boot/build.sh OUT — renders the GRUB and Plymouth themes into OUT/grub and
# OUT/plymouth. No root needed; the grub step and boot/preview install from here.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:?usage: boot/build.sh OUT}"

# Layout shared by the GRUB theme and the Plymouth script.
MARGIN=64  # from the screen edge to the corner text
LINE=24    # between the two corner lines
TEXT_PT=11 # corner text, and the splash's log
MENU_PT=12 # menu entries
LOGO_PX=88
LOGO_AT=42 # logo centre, % of the screen height
BAR_GAP=40 # logo to the splash's progress bar, where the menu starts

# No timestamps in the PNGs, so an unchanged palette builds identical files
# and boot/install.sh can skip the initramfs rebuild.
magick() { command magick "${@:1:$#-1}" -define png:exclude-chunks=date,time "${@: -1}"; }
# boot/logo.svg or boot/logo.png when there is one, Debian's swirl otherwise.
LOGO=/usr/share/icons/desktop-base/scalable/emblems/emblem-debian-white.svg
for f in "$SRC/logo.svg" "$SRC/logo.png"; do
    [ -f "$f" ] && LOGO="$f" && break
done

# DMS's palette, generated from the wallpaper; blue-grey without DMS.
eval "$(
    python3 - "$HOME/.cache/dms/dms-colors.json" <<'PY'
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

# DMS's fonts, resolved as the user so ~/.local/share/fonts counts.
read_fonts() {
    python3 - "$HOME/.config/dms/settings.json" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    s = {}
print(s.get("fontFamily") or "sans")
print(s.get("monoFontFamily") or "monospace")
PY
}
# font_file <family> <generic>: a missing family falls back to the generic one,
# so a monospace slot stays monospace.
font_file() {
    local want="$1" have
    [ "$1" = "$2" ] && {
        fc-match -f '%{file}' "$1"
        return
    }
    have="$(fc-match -f '%{family}' "$1")"
    case ",${have,,}," in
    *",${1,,},"*) ;;
    *)
        want="$2"
        echo "boot/build.sh: DMS font '$1' isn't installed, using $(fc-match -f '%{family[0]}' "$2")" >&2
        ;;
    esac
    fc-match -f '%{file}' "$want"
}
{
    read -r SANS_WANT
    read -r MONO_WANT
} < <(read_fonts)
SANS_FILE="$(font_file "$SANS_WANT" sans)"
MONO_FILE="$(font_file "$MONO_WANT" monospace)"
SANS="$(fc-scan -f '%{family[0]}\n' "$SANS_FILE" | head -1)"
MONO="$(fc-scan -f '%{family[0]}\n' "$MONO_FILE" | head -1)"

# GRUB looks fonts up by the name grub-mkfont stores in the .pf2.
pf2() {
    grub-mkfont -s "$2" -o "$3" "$1"
    python3 -c 'import sys
d = open(sys.argv[1], "rb").read()
i = d.index(b"NAME") + 8
print(d[i:d.index(b"\0", i)].decode())' "$3"
}

# The DMS wallpaper, so boot leads into the login screen; a flat colour without one.
wallpaper() {
    local path
    path="$(sed -n 's/.*"wallpaperPath": *"\([^"]*\)".*/\1/p' \
        "$HOME/.local/state/dms/session.json" \
        "$HOME/.local/state/DankMaterialShell/session.json" 2>/dev/null | head -1)"
    [ -f "$path" ] && printf '%s' "$path"
}

backdrop() {
    local src
    src="$(wallpaper || true)"
    if [ -n "$src" ]; then
        magick "${src}[0]" -resize 1920x1080^ -gravity center -extent 1920x1080 \
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

# Square, so a wide logo keeps its shape in GRUB's fixed-size image box. SVG
# goes through rsvg-convert so the result doesn't depend on ImageMagick's delegates.
logo() {
    local src="$LOGO"
    if [ "${LOGO##*.}" = svg ]; then
        rsvg-convert -w "$(($2 * 4))" -h "$(($2 * 4))" --keep-aspect-ratio \
            -o "$OUT/logo-src.png" "$LOGO"
        src="$OUT/logo-src.png"
    fi
    magick -background none "$src" -resize "${2}x${2}" \
        -gravity center -extent "${2}x${2}" "PNG32:$1"
    rm -f "$OUT/logo-src.png"
}

HOST="$(hostname)"
OS="$(. /etc/os-release && echo "${NAME%% *} $VERSION_ID ${VERSION_CODENAME}" | tr 'A-Z' 'a-z')"

# Points to pixels at 96 dpi, Plymouth's resolution.
px() { echo $((($1 * 96 + 36) / 72)); }

# GRUB fonts aren't antialiased, so fixed text is drawn as images.
# Adds @NAME_W@, @NAME_H@ and @NAME_R@ (right-aligned left edge) to VARS.
VARS=()
text() {
    local out="$1" name="$2" color="$3" font="$4" w h
    shift 4
    magick -background none -fill "$color" -font "$font" -density 96 -pointsize "$TEXT_PT" \
        "label:$*" "PNG32:$out"
    read -r w h < <(magick identify -format '%w %h\n' "$out")
    VARS+=(-e "s|@${name}_W@|$w|g" -e "s|@${name}_H@|$h|g" -e "s|@${name}_R@|$((w + MARGIN))|g")
}

fill() {
    local args=(-e "s|@HOST@|$HOST|g" -e "s|@OS@|$OS|g" "${VARS[@]}") k rgb
    for k in BG FG SUB MUTED ACCENT; do
        rgb="${k}_RGB"
        args+=(-e "s|@${k}_RGB@|${!rgb}|g" -e "s|@$k@|${!k}|g")
    done
    sed "${args[@]}" "$1" >"$2"
}

mkdir -p "$OUT/grub" "$OUT/plymouth"

# Placeholders both templates share: the layout above and the fonts.
VARS+=(
    -e "s|@MARGIN@|$MARGIN|g" -e "s|@LINE@|$LINE|g" -e "s|@TEXT_PT@|$TEXT_PT|g"
    -e "s|@LOGO_PX@|$LOGO_PX|g" -e "s|@LOGO_HALF@|$((LOGO_PX / 2))|g"
    -e "s|@LOGO_AT@|$LOGO_AT|g" -e "s|@BAR_GAP@|$BAR_GAP|g"
    -e "s|@MENU_AT@|$((LOGO_PX / 2 + BAR_GAP))|g"
    -e "s|@CORNER_1@|$((MARGIN + 2 * LINE))|g" -e "s|@CORNER_0@|$((MARGIN + LINE))|g"
    -e "s|@SANS@|$SANS|g" -e "s|@MONO@|$MONO|g"
    -e "s|@MENU_FONT@|$(pf2 "$SANS_FILE" "$(px "$MENU_PT")" "$OUT/grub/menu.pf2")|g"
    -e "s|@MONO_FONT@|$(pf2 "$MONO_FILE" "$(px "$TEXT_PT")" "$OUT/grub/mono.pf2")|g"
)
text "$OUT/grub/host.png" HOST "$FG" "$SANS_FILE" "$HOST"
text "$OUT/grub/os.png" OS "$MUTED" "$SANS_FILE" "$OS  ·  boot menu"
text "$OUT/grub/keys.png" KEYS "$SUB" "$MONO_FILE" "↑↓ select   enter boot   e edit"
fill "$SRC/grub/theme.txt" "$OUT/grub/theme.txt"
backdrop "$OUT/grub/background.png"
logo "$OUT/grub/logo.png" "$LOGO_PX"
pill "$OUT/grub" select "${ACCENT}2e" "${ACCENT}55"
pill "$OUT/grub" item none none

# Shipped in the theme folder; boot/install.sh adds it to the initramfs fontconfig.
cp "$SANS_FILE" "$OUT/plymouth/sans.${SANS_FILE##*.}"
cp "$MONO_FILE" "$OUT/plymouth/mono.${MONO_FILE##*.}"
cp "$SRC/plymouth/dotfiles.plymouth" "$OUT/plymouth/"
fill "$SRC/plymouth/dotfiles.script" "$OUT/plymouth/dotfiles.script"
cp "$OUT/grub/background.png" "$OUT/plymouth/background.png"
logo "$OUT/plymouth/logo.png" "$LOGO_PX"
magick -size 200x2 "xc:$TRACK" "PNG32:$OUT/plymouth/track.png"
magick -size 200x2 "xc:$ACCENT" "PNG32:$OUT/plymouth/bar.png"
