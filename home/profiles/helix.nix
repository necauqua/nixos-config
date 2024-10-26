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
        nil.command = "${nil}/bin/nil";
        zls.command = "${zls}/bin/zls";
        rust-analyzer = {
          command = "${rust-analyzer}/bin/rust-analyzer";
          config.checkOnSave.command = "clippy";
        };
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
          language-servers = [ "nil" ];
          formatter.command = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
          auto-format = true;
        }
        {
          name = "rust";
          language-servers = [ "rust-analyzer" ];
        }
        {
          name = "python";
          language-servers = [ "pylsp" ];
        }
        {
          name = "lua";
          language-servers = [ "luals" ];
        }
        {
          name = "zig";
          language-servers = [ "zls" ];
        }
      ];
    };
  };
}
