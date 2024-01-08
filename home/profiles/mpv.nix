{ config, pkgs, ... }: {
  programs.mpv = {
    enable = !config.headless;

    package = (pkgs.mpv.override {
      scripts = [ pkgs.mpvScripts.mpris ]; # add an essential script lol
    });
    config = {
      volume = 60;
      volume-max = 200;
      pause = true;
      save-position-on-quit = true;

      audio-display = false;
      term-osd-bar = true;
      term-osd-bar-chars = "┣━╉─┨";

      screenshot-format = "png";
      screenshot-template = "mpv-1%tY%tm%td%tH%tM%tS%01n";

      hwdec = true;
      hwdec-codecs = "all";
      profile = "gpu-hq";
    };
    bindings = {
      "9" = "add ao-volume -1";
      "/" = "add ao-volume -1";
      "0" = "add ao-volume 1";
      "*" = "add ao-volume 1";

      WHEEL_LEFT = "seek 10";
      WHEEL_RIGHT = "seek -10";
      WHEEL_UP = "add ao-volume 1";
      WHEEL_DOWN = "add ao-volume -1";

      VOLUME_UP = "add ao-volume 1";
      VOLUME_DOWN = "add ao-volume -1";

      # reload file - useful when YouTube stream link expires
      "Ctrl+r" = "loadfile \${path} replace";

      # yank same as in vim or luakit
      y = "run \"/usr/bin/env\" \"bash\" \"-c\" \"echo -n '\${path}' | xclip -i\"; show-text \"Path yanked: \${path}\"";
      Y = "run \"/usr/bin/env\" \"bash\" \"-c\" \"echo -n '\${path}' | xclip -i -sel clip\"; show-text \"Path yanked to clipboard: \${path}\"";

      # disable pause (there is space, huh) for p- clipboard commands
      p = "ignore";
      # same for progress, there is 'o' button
      P = "ignore";
    };
  };
}
