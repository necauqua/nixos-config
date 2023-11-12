{ pkgs, ... }: {
  programs.git = {
    enable = true;
    userName = "Anton Bulakh";
    userEmail = "him@necauq.ua";
    aliases.rtag = "!f(){ git tag --message=\"Release \${1}\n\" \${1}; }; f";
    signing = {
      key = "29511C06755C211BB3D3419342997635A54BA55B";
      signByDefault = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      core.autocrlf = "input";
      push.followTags = true;
      push.default = "current";
      pull.ff = "only";
      fetch.prune = "true";

      # delta settings
      core.pager = "${pkgs.delta}/bin/delta";
      interactive.diffFilter = "${pkgs.delta}/bin/delta --color-only";
      "add.interactive".useBuiltin = false;
      delta = { navigate = true; light = false; };
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };
}