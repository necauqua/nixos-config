{ flake-inputs, lib, ... }: {
  nix = {
    settings = {
      trusted-users = [ "necauqua" ];
      trusted-substituters = lib.mkAfter [
        "https://necauqua.cachix.org"
      ];
      trusted-public-keys = [
        "necauqua.cachix.org-1:XG5McOG0XwQ9kayUuEiEn0cPoLAMvc2TVs3fXqv/7Uc="
      ];
      auto-optimise-store = true;
    };
    registry = {
      # pin nixpkgs for speed
      nixpkgs.flake = flake-inputs.nixpkgs;
      # sudo nixos-rebuild switch --flake <main / local>
      # well, for the first setup the full git url would be needed ¯\_(ツ)_/¯
      main = {
        from = { id = "main"; type = "indirect"; };
        to = { type = "sourcehut"; owner = "~necauqua"; repo = "nixos-config"; };
        exact = false;
      };
      local = {
        from = { id = "local"; type = "indirect"; };
        to = { type = "path"; path = "/home/necauqua/projects/nixos-config"; };
        exact = false;
      };
    };
  };
  nixpkgs.config.allowUnfree = true;

  # this takes forever and only needed by some fish completions
  documentation.man.generateCaches = false;
}
