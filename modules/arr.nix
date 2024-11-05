{ pkgs-future, ... }: {
  services =
    let yup = { enable = true; openFirewall = true; };
    in {
      jellyfin = yup;
      prowlarr = yup;
      radarr = yup // { user = "necauqua"; group = "users"; };
      sonarr = yup // { user = "necauqua"; group = "users"; };
      jellyseerr = yup;
    };

  # update jellyfin to 10.10 because cringe
  nixpkgs.overlays = [ (final: prev: { jellyfin = pkgs-future.jellyfin; }) ];

  custom.services = [
    { name = "jellyfin"; port = 8096; }
    { name = "prowlarr"; port = 9696; }
    { name = "radarr"; port = 7878; }
    { name = "sonarr"; port = 8989; }
    { name = "jellyseerr"; port = 5055; }
  ];
}
