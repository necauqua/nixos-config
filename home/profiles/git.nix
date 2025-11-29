{ pkgs, ... }: {
  programs.git = {
    enable = true;
    signing = {
      key = "/home/necauqua/.ssh/id_ed25519_sk.pub";
      signByDefault = true;
      format = "ssh";
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
