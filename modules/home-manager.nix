{ config, flake-inputs, hm-profiles, pkgs-stable, ... }: {
  imports = [
    flake-inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.necauqua = flake-inputs.self.homeModules.main;
    extraSpecialArgs = {
      inherit flake-inputs pkgs-stable;
      profiles = hm-profiles;
      system-config = config;
    };
  };
}
