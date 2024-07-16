{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      right_format = "$directory";
      character = {
        success_symbol = "λ";
        error_symbol = "λ";
      };
      directory = {
        truncation_length = 10;
        fish_style_pwd_dir_length = 1;
      };
      status = {
        disabled = false;
        format = "[$status](red)";
        pipestatus = true;
        pipestatus_format = "[$pipestatus](red) ";
      };
      nix_shell = {
        symbol = "❄️";
        impure_msg = "";
      };
      git_branch = {
        format = "on [⌥](purple) [$branch(:$remote_branch)](#ff6611) ";
        only_attached = true;
      };
      git_commit.format = "on [⌥](purple) [$hash](#ffaa33) ";
      git_status = {
        format = "(\\([$ahead_behind](#aaaaaa)\\) )(\\[$conflicted$stashed$staged$renamed$modified$deleted$untracked\\] )";
        conflicted = "=$count";
        stashed = "\\$$count";
        staged = "[+$count](#33cc33)";
        renamed = "[~$count](#6666ff)";
        modified = "[~$count](#6666ff)";
        deleted = "[-$count](#cc3333)";
        untracked = "[#$count](#cc3333)";
        ahead = "↑$count";
        behind = "↓$count";
        diverged = "↑$ahead_count↓$behind_count";
      };
      aws.disabled = true;
    };
  };
}
