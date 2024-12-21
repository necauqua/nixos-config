{
  # at least sonarr depends on those for now
  nixpkgs.config.permittedInsecurePackages = [
    "aspnetcore-runtime-6.0.36"
    "aspnetcore-runtime-wrapped-6.0.36"
    "dotnet-sdk-6.0.428"
    "dotnet-sdk-wrapped-6.0.428"
  ];
  services =
    let yup = { enable = true; openFirewall = true; };
    in {
      jellyfin = yup;
      prowlarr = yup;
      radarr = yup // { user = "necauqua"; group = "users"; };
      sonarr = yup // { user = "necauqua"; group = "users"; };
      jellyseerr = yup;
    };

  custom.services = [
    { name = "jellyfin"; port = 8096; }
    { name = "prowlarr"; port = 9696; }
    { name = "radarr"; port = 7878; }
    { name = "sonarr"; port = 8989; }
    { name = "jellyseerr"; port = 5055; }
  ];
}
