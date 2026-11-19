D2_VERSION=0.9.0
TYPST_VERSION=0.15.1
VHS_VERSION=0.12.1
TTYD_VERSION=1.7.7

register_step animation \
    --desc "Animation and visualization: manim, manim-slides, marimo, ffmpeg, LaTeX, graphviz, d2, typst, vhs" \
    --group dev --root --needs python \
    --provides manim marimo ffmpeg latex dot gnuplot d2 typst vhs

step_animation() {
    log "Installing apt packages for manim and rendering"
    apt_install \
        ffmpeg imagemagick graphviz gnuplot-nox asciinema \
        libcairo2-dev libpango1.0-dev pkg-config build-essential \
        texlive-latex-base texlive-latex-recommended texlive-latex-extra \
        texlive-fonts-recommended texlive-science dvisvgm

    log "Installing d2, typst, vhs, ttyd with mise (ttyd is vhs's terminal backend)"
    mise use --global d2@$D2_VERSION typst@$TYPST_VERSION vhs@$VHS_VERSION ttyd@$TTYD_VERSION

    log "Installing manim, plugins, manim-slides, marimo with uv"
    # manim-physics pins manim<0.19, which it doesn't need; override the pin
    # shellcheck disable=SC2155
    local pins="$(mktemp)"
    echo 'manim>=0.22' >"$pins"
    uv tool install manim --overrides "$pins" --with manim-dsa --with manim-physics
    rm -f "$pins"
    uv tool install manim-slides
    uv tool install marimo

    log "Installing the Cascadia Code font manim-dsa asks for"
    mkdir -p "$HOME/.local/share/fonts/CascadiaCode"
    cp "$HOME"/.local/share/uv/tools/manim/lib/python*/site-packages/manim_dsa/fonts/CascadiaCode.ttf \
        "$HOME/.local/share/fonts/CascadiaCode/"
    fc-cache -f "$HOME/.local/share/fonts/CascadiaCode" >/dev/null
}
