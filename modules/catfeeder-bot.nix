{ inputs, config, ... }: {
  imports = [
    inputs.catfeeder-bot.nixosModules.default
  ];

  secrets.catfeeder-secrets = { };

  services.catfeeder-bot = {
    enable = true;
    secretsFile = config.age.secrets.catfeeder-secrets.path;
  };
}
