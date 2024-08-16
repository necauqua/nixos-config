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
      language-server = {
        nil.command = "${pkgs.nil}/bin/nil";
        rust-analyzer = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          config.checkOnSave.command = "clippy";
        };
        pylsp.command = "${pkgs.python3Packages.python-lsp-server}/bin/pylsp";
        luals.command = "${pkgs.lua-language-server}/bin/lua-language-server";
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
      ];
    };
  };
}
