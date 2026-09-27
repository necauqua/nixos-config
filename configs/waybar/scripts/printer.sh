#!/usr/bin/env bash

# Progress of the current print on the Moonraker/Klipper 3D printer. The
# output is empty (and waybar hides the module) when the printer does not
# answer, or when it does not print.

printer=${PRINTER_URL:-http://u1.lan}

curl -sf -m 3 "$printer/printer/objects/query?print_stats&virtual_sdcard" \
    | jq --compact-output '
        .result.status as $s
        | $s.print_stats as $p
        | select($p.state == "printing" or $p.state == "paused")
        | ($s.virtual_sdcard.progress // 0) as $progress
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
        }' \
    || true
