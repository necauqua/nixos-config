{ config, ... }: {

  secrets.restic = { };

  services.restic.backups.offsite = {
    environmentFile = config.age.secrets.restic.path;

    paths = [ "/home/necauqua" ];

    extraBackupArgs = [
      "--exclude-caches"
      "--skip-if-unchanged"
      "--limit-upload"
      "5120" # 5 MiB/s
    ];

    # the repository is append only, so it is pruned on offsite itself
    pruneOpts = [ ];

    timerConfig = {
      OnCalendar = "05:00";
      Persistent = true;
    };
    inhibitsSleep = true;

    # bare name (no / at the start) excludes every match at any depth
    exclude = [
      ".direnv"
      ".pnpm-store"
      "build"
      "out"
      "node_modules"
      "venv"
      ".venv"
      ".gradle"
      ".zig-cache"

      "Cache"
      "Code Cache"
      "CacheStorage"
      "CachedData"

      "/home/necauqua/.cache"
      "/home/necauqua/.rustup"
      "/home/necauqua/.npm"
      "/home/necauqua/.bun"
      "/home/necauqua/.m2"
      "/home/necauqua/.ivy2"
      "/home/necauqua/.wine"

      "/home/necauqua/.bitcoin/blocks"
      "/home/necauqua/.bitcoin/chainstate"
      "/home/necauqua/.monero/blockchain"

      "/home/necauqua/downloads"

      "/home/necauqua/.local/share/containers"
      "/home/necauqua/.local/share/Steam"
      "/home/necauqua/.local/share/noita-launcher"
      "/home/necauqua/.local/share/zed"
      "/home/necauqua/.local/share/umu"
      "/home/necauqua/.local/share/lutris"
      "/home/necauqua/.local/share/JetBrains"
      "/home/necauqua/.local/share/pnpm"
      "/home/necauqua/.local/share/Trash"
      "/home/necauqua/.local/share/TelegramDesktop"

      "/home/necauqua/.config/discord"
    ];
  };
}
