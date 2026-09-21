{ flake-inputs, config, ... }:
{
  imports = [
    flake-inputs.twitch-archiver.nixosModules.default
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

  # an instance reads the key once when it starts, so a rotated key needs a
  # new instance: the trigger changes the unit, and with it the generation
  # tag, which makes the switcher cut over to an instance with the new key
  systemd.services."twitch-archiver@".restartTriggers = [
    config.secrets.elastic-key.hash
  ];
}
