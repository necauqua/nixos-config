{ config, pkgs, lib, ... }:
let
  enable = !config.headless;
in
{
  programs.broot.settings.verbs = lib.mkIf enable [
    {
      invocation = "mpv";
      execution = "fish -c \"mpvt {file}\"";
      leave_broot = false;
    }
  ];
  programs.fish.functions = lib.mkIf enable {
    mpvt = "mpv --wid=$WINDOWID $argv";
    yt-music = ''
      echo -e '\033[?25l' # hide cursor
      mpv "ytdl://ytsearch:$argv" \
        --no-video \
        --no-resume-playback \
        --no-pause \
        --load-unsafe-playlists \
        --msg-level=all=error,statusline=status
      echo -e '\033[?25h' # show it back
    '';
    yt-search = ''
      mpv "ytdl://ytsearch:$argv" \
        --wid=$WINDOWID \
        --load-unsafe-playlists \
        --really-quiet \
        --no-pause
    '';
  };

  programs.mpv = {
    inherit enable;

    package = pkgs.mpv.override {
      scripts = [ pkgs.mpvScripts.mpris ]; # add an essential script lol
    };
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
