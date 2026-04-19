{ inputs, config, ... }: {
  imports = [
    inputs.twitch-archiver.nixosModules.default
  ];

  age.secrets.elastic-key.file = ../secrets/elastic-key.age;

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
