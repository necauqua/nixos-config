#!/usr/bin/env bash

# Progress of the current print on the Moonraker/Klipper 3D printer. The
# output is empty (and waybar hides the module) when the printer does not
# answer, or when it does not print.
#
# The progress is the position in the G-code moves of the file, between the
# gcode_start_byte and gcode_end_byte of its metadata. This is the
# "file-relative" progress, which Mainsail and Fluidd show by default.
# virtual_sdcard.progress is the position in the whole file, so it also counts
# the thumbnails before the moves and the slicer config after them, and stops
# far below 100%. Klipper also has display_status.progress, but it is not the
# value of the web UI: it comes from the M73 commands of the slicer, which
# change only in whole percents at some points of the file, and it is only as
# accurate as the time estimate of the slicer.
#
# The metadata does not change during a print, so it is requested once per
# print and kept in a cache file.

printer=${PRINTER_URL:-http://u1.lan}
cache=${XDG_RUNTIME_DIR:-/tmp}/waybar-printer-meta

status=$(curl -sf -m 3 "$printer/printer/objects/query?print_stats&virtual_sdcard") || exit 0

IFS=$'\t' read -r state filename < <(jq -r '.result.status.print_stats | "\(.state)\t\(.filename)"' <<<"$status")
if [[ $state != printing && $state != paused ]]; then
    rm -f "$cache"
    exit 0
fi

{ IFS= read -r cached; read -r start end; } 2>/dev/null <"$cache"
if [[ $cached != "$filename" ]]; then
    start= end=
    read -r start end < <(
        curl -sfG -m 3 --data-urlencode "filename=$filename" "$printer/server/files/metadata" \
            | jq -r '.result | "\(.gcode_start_byte) \(.gcode_end_byte)"'
    )
    [[ -n $start ]] && printf '%s\n%s %s\n' "$filename" "$start" "$end" >"$cache"
fi

jq --compact-output --argjson start "${start:-null}" --argjson end "${end:-null}" '
    .result.status as $s
    | $s.print_stats as $p
    | $s.virtual_sdcard as $sd
    | (if $start != null and $end != null and $end > $start then
          ($sd.file_position - $start) / ($end - $start)
          | if . < 0 then 0 elif . > 1 then 1 else . end
        else
          $sd.progress // 0
        end) as $progress
    | def hm: (. / 3600 | floor | tostring) + "h " + (. % 3600 / 60 | floor | tostring) + "m";
    {
      text: (($progress * 100 | floor | tostring) + "%"),
      percentage: ($progress * 100 | floor),
      class: $p.state,
      tooltip: ([
          $p.filename,
          ($p.info.current_layer // null | if . then "Layer: \(.)/\($p.info.total_layer)" else empty end),
          "Elapsed: \($p.print_duration | hm)",
          (if $progress > 0 then "Left: \($p.print_duration / $progress - $p.print_duration | hm)" else empty end)
        ] | join("\n")),
    }' <<<"$status" \
    || true
