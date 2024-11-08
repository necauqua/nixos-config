{ config, ... }: {

  age.secrets.borg-key.file = ../secrets/borg-key;
  age.secrets.borg-pass.file = ../secrets/borg-pass;

  environment.systemPackages = [
    config.services.borgbackup.package
  ];

  services.borgbackup.jobs.offsite = {
    archiveBaseName = "home";
    dateFormat = "+1%Y-%m-%dT%H:%M:%S";
    repo = "borg@necauq.ua:.";
    encryption.mode = "repokey-blake2";
    encryption.passCommand = "cat ${config.age.secrets.borg-pass.path}";
    environment.BORG_RSH = "ssh -i ${config.age.secrets.borg-key.path} -p 5555";

    preHook = ''
      extraCreateArgs=--exclude-caches # nix-side extraCreateArgs are broken atm
      cd /home/necauqua # ugh patterns are relative to cwd
    '';
    paths = [ "." ];

    startAt = "daily";
    persistentTimer = true;
    inhibitsSleep = true;

    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 3;
      yearly = -1;
    };

    exclude = [
      "sh:**/.direnv"
      "sh:**/.pnpm-store"
      "sh:**/build"
      "sh:**/out"
      "sh:**/node_modules"
      "sh:**/venv"
      "sh:**/.venv"
      "sh:**/.gradle"

      "sh:**/Cache"
      "sh:**/Code Cache"
      "sh:**/CacheStorage"
      "sh:**/CachedData"

      ".cache"
      ".rustup"
      ".npm"
      ".nx"
      ".m2"
      ".ivy2"
      ".tldrc"
      ".vscode"
      ".wine"
      ".mozilla"
      ".ollama"

      "downloads"

      ".local/share/pnpm"
      ".local/share/baloo"
      ".local/share/lutris"
      ".local/share/Trash"
      ".local/share/Steam"
      ".local/share/TelegramDesktop"
      ".local/share/JetBrains"
      ".local/share/fish/generated_completions"

      ".config/discord"
      ".config/JetBrains"

      "projects/android/_SDK_"
    ];
  };
}
