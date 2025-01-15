{ config, pkgs, ... }:
let
  git = config.programs.git;
  private-revset = "(bookmarks() | remote_bookmarks())..((description(glob:'wip:*') | description(glob:'private:*') | description(exact:'megamerge\\n')) ~ ::trunk())";
in
{
  programs.jujutsu.enable = true;
  programs.jujutsu.settings = {
    user.name = git.userName;
    user.email = git.userEmail;

    git = {
      fetch = [ "origin" "upstream" ];
      push-bookmark-prefix = "necauqua/push-";
      private-commits = private-revset;
    };
    snapshot.auto-track = "none()";

    signing = {
      backend = "gpg";
      key = git.signing.key;
      sign-all = git.signing.signByDefault;
    };

    ui = {
      default-command = "log";
      diff-editor = ":builtin";
    };
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
      tug = [ "bookmark" "move" "--from" "heads(::@- & bookmarks())" "--to" "@-" ];
      diffp = [ "diff" "-r" "@-" ];
      hide = [ "abandon" ];
      sq = [ "squash" ];
      push = [ "git" "push" ];
      fetch = [ "git" "fetch" ];

      count = [ "util" "exec" "--" "sh" "-c" "jj log -r \"\${1:-all()}\" -T '\".\"' --no-graph | wc -c" "--" ];
    };

    colors = {
      "node".bold = true;
      "node elided".fg = "bright black";
      "node wcc".fg = "green";
      "node immutable".fg = "bright cyan";
      "node private".fg = "#7b449c"; # purple
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
          if(description == "megamerge\n", "⊕"),
          if(immutable, "◆"),
          if(self.contained_in("${private-revset}"), "⊘"),
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
            if(self.contained_in("${private-revset}"), label("private", content)),
            if(conflict, label("conflict", content)),
            if(current_working_copy, label("working_copy", content)),
            label("normal", content)
          )
        )
      '';
    };
  };
}
