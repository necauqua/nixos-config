{ pkgs, ... }: {
  programs.helix = {
    enable = true;
    settings = {
      editor = {
        bufferline = "multiple";
        cursorline = true;
        lsp.display-inlay-hints = true;
        indent-guides.render = true;
      };
      keys.normal = {
        "C-q" = "hover";
        "C-k" = "command_palette";
      };
    };
    languages = {
      language-server = with pkgs; {
        rust-analyzer.config.checkOnSave.command = "clippy";
        pylsp = {
          config.pylsp.plugins.rope_autoimport.enabled = true;
          command =
            let
              combined = python3.withPackages (p: with p; [
                python-lsp-server
                python-lsp-black
                pylsp-rope
                python-lsp-ruff
              ]);
            in
            "${combined}/bin/pylsp";
        };
        luals.command = "${lua-language-server}/bin/lua-language-server";
      };
      language = [
        {
          name = "nix";
          indent = { tab-width = 2; unit = "  "; };
          formatter.command = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
          auto-format = true;
        }
        {
          name = "lua";
          language-servers = [ "luals" ];
        }
      ];
    };
  };
}
