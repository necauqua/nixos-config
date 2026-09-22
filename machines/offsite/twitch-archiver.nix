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
      "nuttyssa"
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

  # LLM said that the service wont restart if the key is rotated
  # because agenix path is stable 🤷
  systemd.services."twitch-archiver@".restartTriggers = [
    config.secrets.elastic-key.hash
  ];
}
