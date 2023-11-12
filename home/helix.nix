{ pkgs, ... }: {
  programs.helix = {
    enable = true;
    settings = {
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
      ];
    };
  };
}
