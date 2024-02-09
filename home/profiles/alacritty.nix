{ config, pkgs, ... }: {

  home.packages = [
    # make launching termapps work in KDE
    (pkgs.writeShellScriptBin "konsole" ''
      new_args=()

      while [[ $# -gt 0 ]]; do
        case $1 in
          -qwindowicon)
            shift 2
            ;;
          -qwindowtitle)
            new_args+=("--title" "$2")
            shift 2
            ;;
          --workdir)
            new_args+=("--working-directory" "$2")
            shift 2
            ;;
          *)
            new_args+=("$1")
            shift
            ;;
        esac
      done
      alacritty "''${new_args[@]}"
    '')
  ];

  programs.alacritty = {
    enable = !config.headless;
    settings = {
      window = {
        dimensions = {
          columns = 80;
          lines = 24;
        };
        resize_increments = true;
      };
      font = let font = "JetBrains Mono"; in {
        normal.family = font;
        italic.family = font;
        bold_italic.family = font;
        size = 14;
      };
      cursor.style.blinking = "On";
      hints = {
        alphabet = "jfkdls;ahgurieowpq";
        enabled = [
          {
            hyperlinks = true;
            command = "xdg-open";
            mouse.enabled = true;
          }
          {
            regex = "(mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\\u0000-\\u001F\\u007F-\\u009F<>\" {-}\\\\^⟨⟩`]+";
            command = "xdg-open";
            post_processing = true;
            mouse = {
              enabled = true;
              mods = "None";
            };
            binding = {
              key = "U";
              mods = "Control|Shift";
            };
          }
        ];
      };
      keyboard.bindings = [
        {
          key = "T";
          mods = "Control";
          command = {
            program = "bash";
            args = [
              "-c"
              ''
                cur=`cat ~/.config/alacritty/opacity.toml | cut -d= -f2 || true`
                if [[ "$cur" = 0.5 ]]; then
                  new=1.0
                else
                  new=0.5
                fi
                echo "window.opacity=$new" > ~/.config/alacritty/opacity.toml
              ''
            ];
          };
        }
      ];
      import = [ "~/.config/alacritty/opacity.toml" ];
      colors = {
        primary = {
          background = "#2e3440";
          foreground = "#d8dee9";
          dim_foreground = "#a5abb6";
        };
        cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        vi_mode_cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        selection = {
          text = "CellForeground";
          background = "#4c566a";
        };
        search.matches = {
          foreground = "CellBackground";
          background = "#88c0d0";
        };
        normal = {
          black = "#3b4252";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#88c0d0";
          white = "#e5e9f0";
        };
        bright = {
          black = "#4c566a";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#8fbcbb";
          white = "#eceff4";
        };
        dim = {
          black = "#373e4d";
          red = "#94545d";
          green = "#809575";
          yellow = "#b29e75";
          blue = "#68809a";
          magenta = "#8c738c";
          cyan = "#6d96a5";
          white = "#aeb3bb";
        };
      };
    };
  };
}
