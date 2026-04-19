{ inputs, config, ... }: {
  imports = [
    inputs.twitch-archiver.nixosModules.default
  ];

  secrets.elastic-key = { };

  services.twitch-archiver = {
    enable = true;
    channels = [
      "necauqua"
      "dunkorslam"
      "snekgregory"
      "nutty_mitchell"
      "lasiace"
      "yolksyb13"
      "vexilus_"
      "peterce3"
    ];
    elastic = {
      url = "http://localhost:9200";
      apiKeyFile = config.age.secrets.elastic-key.path;
    };
  };
}
