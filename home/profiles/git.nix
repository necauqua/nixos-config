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
      diff.external = "${pkgs.difftastic}/bin/difft";
    };
  };
}
