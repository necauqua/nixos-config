{ config, pkgs, ... }:
let
  git = config.programs.git;
  private-revset = "(bookmarks() | remote_bookmarks())..((description(glob:'wip:*') | description(glob:'private:*') | description(exact:'megamerge\\n')) ~ ::trunk())";
in
{
  programs.jujutsu.enable = true;
  programs.jujutsu.settings = {
    user.name = git.settings.user.name;
    user.email = git.settings.user.email;

    git = {
      fetch = [ "glob:*" ];
      sign-on-push = true;
      private-commits = private-revset;
    };
    snapshot.auto-track = "none()";

    signing = {
      backend = "ssh";
      key = git.signing.key;
      signing.behavior = "drop";
    };

    ui = {
      default-command = "log";
      diff-editor = ":builtin";
      show-cryptographic-signatures = true;
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
      drop = [ "abandon" ];
      sq = [ "squash" ];
      push = [ "git" "push" ];
      fetch = [ "git" "fetch" ];
      add = [ "file" "track" ];

      count = [ "util" "exec" "--" "sh" "-c" "jj log -r \"\${1:-all()}\" -T '\".\"' --no-graph | wc -c" "--" ];
    };

    colors = {
      "node".bold = true;
      "node elided".fg = "bright black";
      "node wcc".fg = "green";
      "node immutable".fg = "bright cyan";
      "node private".fg = "#7b449c"; # purple
      "node normal".bold = false;
      "change_offset" = {
        fg = "red";
        bold = false;
        dim = false;
      };
    };

    templates = {
      git_push_bookmark = "\"necauqua/push-\" ++ change_id.short()";
      op_log_node = "if(current_operation, \"@\", \"○\")";
      log_node = ''
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
      draft_commit_description = ''
        concat(
          description,
          surround(
            "\nJJ: This commit contains the following changes:\n", "",
            indent("JJ:     ", diff.stat(120)),
          ),
          "\nJJ: ignore-rest\n",
          diff.git(),
        )
      '';
    };

    template-aliases = {
      "format_timestamp(ts)" = "ts.ago()";
      "format_short_commit_id(id)" = "id.shortest(7)";
      "format_short_change_id(id)" = ''
        "(" ++ label("change_id prefix", id.shortest().prefix()) ++ ")"
      '';
      "format_short_change_id_with_change_offset(commit)" = ''
        if(commit.hidden() || commit.divergent(),
          "(" ++ label("change_id prefix", commit.change_id().shortest().prefix())
            ++ surround(label("change_offset", "/"), "", commit.change_offset())
            ++ ")",
          format_short_change_id(commit.change_id()),
        )
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
