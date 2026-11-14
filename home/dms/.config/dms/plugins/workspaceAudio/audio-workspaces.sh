#!/usr/bin/env bash
# Prints a JSON array of Hyprland workspace ids that have a running audio stream.
set -u

streams=$(pw-dump | jq -c '[.[]
  | select(.type == "PipeWire:Interface:Node"
           and .info.props["media.class"] == "Stream/Output/Audio"
           and .info.state == "running")
  | {pid: ((.info.props["application.process.id"] // 0) | tonumber), name: (.info.props["media.name"] // "")}]')
clients=$(hyprctl clients -j | jq -c '[.[] | {pid, ws: .workspace.id, title}]')

# Audio is often played by a child process of the window's process.
resolve() {
    local pid=$1
    while [ "$pid" -gt 1 ]; do
        if jq -e --argjson p "$pid" 'any(.[]; .pid == $p)' <<<"$clients" >/dev/null; then
            echo "$pid"; return
        fi
        pid=$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null || echo 0)
    done
    echo 0
}

resolved='[]'
while IFS=$'\t' read -r pid name; do
    [ "$pid" -gt 0 ] || continue
    rp=$(resolve "$pid")
    [ "$rp" -gt 0 ] || continue
    resolved=$(jq -c --argjson p "$rp" --arg n "$name" '. + [{pid: $p, name: $n}]' <<<"$resolved")
done < <(jq -r '.[] | [.pid, .name] | @tsv' <<<"$streams")

# Browsers name every stream "Playback" and share one process across windows, so
# MPRIS (the playing tab's title) picks the window; with no match nothing is marked.
titles=$(playerctl -a -f '{{status}}|{{title}}' metadata 2>/dev/null \
    | sed -n 's/^Playing|\(.\+\)$/\1/p' | jq -R . | jq -sc .)

jq -c --argjson clients "$clients" --argjson titles "${titles:-[]}" '
  [.[] as $s
   | ($clients | map(select(.pid == $s.pid))) as $c
   | ($c | map(.title as $t | select(($s.name != "" and ($t | contains($s.name)))
                                     or any($titles[]; . as $m | $t | contains($m))))) as $m
   | (if ($c | length) == 1 then $c else $m end)[].ws]
  | unique | sort' <<<"$resolved"
