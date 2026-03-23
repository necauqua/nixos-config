{ config, pkgs, ... }: {
  programs.rofi = {
    enable = pkgs.stdenv.isLinux && !config.headless;
    font = "JetBrains Mono 12";
    terminal = "kitty";
    theme =
      let
        lit = config.lib.formats.rasi.mkLiteral;
      in
      {
        "@import" = "default";
        "*" = {
          background = lit "black/50%";
          foreground = lit "white";
        };
        window = {
          fullscreen = true;
          padding = lit "25%";
          border = 0;
        };
        prompt.enabled = false;
        textbox-prompt-colon.str = "λ";
        entry = {
          text-color = lit "rgba(0, 255, 255, 100%)";
          placeholder = "search";
          placeholder-color = lit "white/50%";
        };
        message = {
          border = 0;
          padding = lit "1ch 0";
        };
        listview = {
          columns = 2;
          fixed-columns = true;
          padding = lit "2ch 0 0 0";
          scrollbar = false;
          dynamic = true;
        };
        element-icon = {
          size = lit "2ch";
          padding = lit "0.25ch 0.25ch 0 0";
        };
        element = {
          padding = lit "0.5ch";
          background-color = lit "transparent";
        };
        "element normal normal".background-color = lit "transparent";
        "element alternate normal".background-color = lit "transparent";
      };
    extraConfig = {
      modi = "window,run,ssh,combi";
      combi-hide-mode-prefix = true;
      dpi = 96;
    };
  };
}
