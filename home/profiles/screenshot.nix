{ config, pkgs, lib, ... }:
let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    # niri and nsxiv are not here on purpose: they come from the inherited
    # PATH, so that niri msg matches the running compositor and nsxiv is the
    # patched one from the nsxiv profile
    runtimeInputs = with pkgs; [
      coreutils
      grim
      jq
      libnotify
      openssh
      slurp
      wl-clipboard-rs
      zenity
    ];
    text = ''
      # Takes a screenshot of a selected region, puts it in the clipboard and
      # shows a notification with actions to open it, save it under a name, or
      # upload it to necauq.ua and put the short link in the clipboard.

      shot=/tmp/last-screenshot.png

      # slurp shows a box for each visible floating window, a click in one
      # selects it. niri IPC gives the position of floating windows only (as
      # tile_pos_in_workspace_view, relative to the output), so a tiled
      # window needs a drag.
      boxes() {
        jq -rn \
          --argjson outputs "$(niri msg -j outputs)" \
          --argjson workspaces "$(niri msg -j workspaces)" \
          --argjson windows "$(niri msg -j windows)" \
          '
            ($workspaces
              | map(select(.is_active and .output != null)
                  | { key: (.id | tostring), value: $outputs[.output].logical })
              | from_entries) as $views
            | $windows[]
            | .layout as $layout
            | select($layout.tile_pos_in_workspace_view != null)
            | $views[.workspace_id | tostring] as $view
            | select($view != null)
            | [
                $view.x + $layout.tile_pos_in_workspace_view[0] + $layout.window_offset_in_tile[0],
                $view.y + $layout.tile_pos_in_workspace_view[1] + $layout.window_offset_in_tile[1],
                $layout.window_size[0],
                $layout.window_size[1]
              ]
            | map(round)
            | "\(.[0]),\(.[1]) \(.[2])x\(.[3])"
          '
      }

      selection=$(boxes | slurp)

      grim -g "$selection" - | tee "$shot" | wl-copy -rt image/png

      res=$(notify-send "Shot the screen" -i "$shot" -A Open -A Save -A Link)

      case "$res" in
        0)
          nsxiv "$shot"
          ;;
        1)
          name=$(zenity --entry --text 'Set the file name' --title 'Save the screenshot')
          mkdir -p "$HOME/images/screenshots"
          cp "$shot" "$HOME/images/screenshots/$name.png"
          ;;
        2)
          name=$(date +1%Y%m%d%H%M%S)
          scp "$shot" "necauq.ua:/var/www/necauqua.dev/images/screenshots/$name.png"
          printf 'uq.rs/s/%s' "$name" | wl-copy -r
          ;;
      esac
    '';
  };
in
{
  home.packages = lib.optionals (pkgs.stdenv.hostPlatform.isLinux && !config.headless) [ screenshot ];
}
