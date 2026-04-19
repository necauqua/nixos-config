{ inputs, config, ... }: {
  imports = [
    inputs.catfeeder-bot.nixosModules.default
  ];

  age.secrets.catfeeder-secrets.file = ../secrets/catfeeder-secrets.age;

  services.catfeeder-bot = {
    enable = true;
    secretsFile = config.age.secrets.catfeeder-secrets.path;
  };
}
