{ config, pkgs, ... }:
let
  git = config.programs.git;
in
{
  programs.jujutsu.enable = true;
  programs.jujutsu.settings = {
    user.name = git.userName;
    user.email = git.userEmail;

    git.auto-local-branch = false;
    git.push-branch-prefix = "necauqua/push-";

    signing = {
      backend = "gpg";
      key = git.signing.key;
      sign-all = git.signing.signByDefault;
    };

    ui.default-command = "log";
    diff.tool = "difft";

    merge-tools.difft = {
      program = "${pkgs.difftastic}/bin/difft";
      diff-args = [
        "--color=always"
        "$left"
        "$right"
      ];
    };

    aliases = {
      all = [ "log" "-r" "all()" ];
      mine = [ "log" "-r" "mine()" ];
      tug = [ "bookmark" "set" "main" "-r" "@-" ];
      diffp = [ "diff" "-r" "@-" ];
      hide = [ "abandon" ];
      sq = [ "squash" ];
      push = [ "git" "push" ];
      fetch = [ "git" "fetch" ];
    };

    colors = {
      "node".bold = true;
      "node elided".fg = "bright black";
      "node wcc".fg = "green";
      "node immutable".fg = "bright cyan";
      "node wip".fg = "yellow";
      "node normal".bold = false;
    };

    templates.op_log_node = ''
      if(current_operation, "@", "○")
    '';
    templates.log_node = ''
      label_node(
        coalesce(
          if(!self, "~"),
          if(root, "┴"),
          if(current_working_copy, "@"),
          if(description.starts_with("nix flake update"), "❄️"),
          if(immutable, "◆"),
          if(description.starts_with("wip: "), "⊘"),
          if(conflict, "×"),
          "○"
        )
      )
    '';

    template-aliases = {
      "format_timestamp(ts)" = "ts.ago()";
      "format_short_commit_id(id)" = "id.shortest(7)";
      "format_short_change_id(id)" = ''
        "(" ++ id.shortest().prefix() ++ ")"
      '';
      "builtin_log_root(a,b)" = ''
        "(" ++ label("change_id prefix", "root") ++ ")"
      '';
      "label_node(content)" = ''
        label("node",
          coalesce(
            if(!self, label("elided", content)),
            if(root, content),
            if(immutable, label("immutable", content)),
            if(description.starts_with("wip: "), label("wip", content)),
            if(conflict, label("conflict", content)),
            if(current_working_copy, label("working_copy", content)),
            label("normal", content)
          )
        )
      '';
    };
  };
}
