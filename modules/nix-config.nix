{ pkgs, flake-inputs, ... }: {

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    settings.trusted-users = [ "root" ];

    # avoid channels altogether and use the input nixpkgs flake
    nixPath = [ "nixpkgs=${flake-inputs.nixpkgs}" ];
  };

  nixpkgs.config.allowUnfree = true;
}
