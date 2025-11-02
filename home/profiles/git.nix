{ pkgs, ... }: {
  programs.git = {
    enable = true;
    signing = {
      key = "29511C06755C211BB3D3419342997635A54BA55B";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "Anton Bulakh";
        email = "him@necauq.ua";
      };
      alias.rtag = "!f(){ git tag --message=\"Release \${1}\n\" \${1}; }; f";
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
