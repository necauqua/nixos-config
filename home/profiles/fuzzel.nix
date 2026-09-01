{ config, pkgs, ... }: {
  programs.fuzzel = {
    enable = pkgs.stdenv.hostPlatform.isLinux && !config.headless;
    settings = {
      main = {
        font = "JetBrains Mono:size=12";
        # rofi had prompt disabled and used "λ" as the prompt-colon;
        # quotes preserve the trailing space.
        prompt = ''"λ "'';
        placeholder = "search";
        terminal = "kitty";
        icons-enabled = "yes";
        layer = "overlay";
        # rofi matched name,generic,exec,categories,keywords
        fields = "name,generic,exec,categories,keywords";
        # centered window; fuzzel can't do "fullscreen + 25% padding"
        # so we pick a roomy centered size that approximates the look.
        width = 60;
        lines = 15;
        horizontal-pad = 24;
        vertical-pad = 16;
        inner-pad = 8;
      };
      colors = {
        # rofi: background = black/50%, foreground = white
        background = "00000080";
        text = "ffffffff";
        prompt = "ffffffff";
        placeholder = "ffffff80";
        # rofi entry text-color = rgba(0,255,255,100%)
        input = "00ffffffff";
        match = "00ffffff";
        selection = "ffffff20";
        selection-text = "ffffffff";
        selection-match = "00ffffff";
        counter = "ffffff80";
        border = "00000000";
      };
      border = {
        width = 0;
        radius = 0;
      };
    };
  };
}
