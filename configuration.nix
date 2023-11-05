{ config, pkgs, lib, username, ... }: {

  imports = [ ./modules ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes repl-flake
      keep-outputs = true
      keep-derivations = true
    '';
    settings = {
      trusted-users = ["root" username];
      auto-optimise-store = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
    # kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "udev.log_priority=3"
      "quiet"
      # fix keychron fn keys
      "hid_apple.fnmode=0"
    ];
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback.out
    ];
    kernelModules = ["v4l2loopback"];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';

    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    supportedFilesystems = [ "zfs" "ntfs" ];
  };

  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";

  swapDevices = [
    {
      device = "/var/swap";
      size = lib.strings.toInt (builtins.readFile (pkgs.runCommand "memory-size" {} ''
        grep MemTotal /proc/meminfo | awk '{print int($2/1024)}' > $out
      ''));
    }
  ];

  powerManagement.cpuFreqGovernor = "performance";

  time.timeZone = "Europe/Kiev";

  networking = {
    hostId = "09e32be7";
    useDHCP = false;
    networkmanager.enable = true;
  };
  # shave off ~5 secs from boot, lol
  # we don't need this
  systemd.services.NetworkManager-wait-online.enable = false;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LANG="en_US.UTF-8";
      LC_TIME="en_GB.UTF-8";
      LC_PAPER="en_GB.UTF-8";
      LC_MEASUREMENT="en_GB.UTF-8";
    };
  };

  # Enable sound
  sound.enable = true;
  hardware = {
    opengl.driSupport32Bit = true;
    bluetooth.enable = true;
  };

  users = {
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
    users.${username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "docker" "dialout" "adbusers" "networkmanager" "wireshark" ];
      # lol
      hashedPassword = "$6$.fpv9TmqXoHSfmj/$ql9VtGHMsyJssreJY0lTINfQkYZSZZnDzAozje4R1jWiih92I.QlHbjmfPeRexBjEM4VfZseEo4R5id/OkK9a1";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoNFwj1SN1LJGT6Pto7hp9kHhWF9RsF0tXMI95Jix5P phone"
      ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      fish
      gparted
      helix
      openssl
      zfs

      polkit_gnome
    ];
    shells = [ pkgs.bashInteractive pkgs.fish ];
    variables = {
      EDITOR = "${pkgs.helix}/bin/hx";

      # makes command-not-found/nix-index automatically run
      # the command in an ephemeral shell if it does not exist
      # but is present in the nix store, this is really cool
      NIX_AUTO_RUN = "1";

      # also make some java guis prettier
      _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=lcd -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel";

      # no idea why is this not a default on an X11 systems
      QT_USE_PHYSICAL_DPI = "1";
    };

    etc = with pkgs; {
      # stable locations for all them javas
      jdk8.source = jdk8;
      jdk11.source = jdk11;
      jdk16.source = adoptopenjdk-hotspot-bin-16;
      jdk17.source = jdk17;

      # also for awesome for lua LSP when editing the config
      # awesome.source = my-pkgs.awesome-git;
      # and the LSP itself
      lua-lsp.source = sumneko-lua-language-server;
      # and rnix-lsp for vscode (for helix it's in the HM config)
      nix-lsp.source = rnix-lsp;
    };

    plasma5.excludePackages = with pkgs.libsForQt5; [
      oxygen
      khelpcenter
      konsole
      print-manager
    ];
  };

  fonts.packages = with pkgs; [
    jetbrains-mono
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
  ];
  programs = {
    adb.enable = true;
    dconf.enable = true;
    fish.enable = true;
    less.envVariables.LESS = "-FRX";
    partition-manager.enable = true;
    steam.enable = true;
    wireshark.enable = true;
  };

  security = {
    sudo.extraConfig = ''
      Defaults passprompt = "[sudo] your password: "
      Defaults pwfeedback
      Defaults insults
    '';
    rtkit.enable = true;
  };

  services = {
    xserver = {
      enable = true;
      dpi = 196;

      excludePackages = [ pkgs.xorg.xorgserver ];
      displayManager = {
        xserverBin = lib.mkForce "${pkgs.xserver-bug865}/bin/X";
        # xserverArgs = ["-extension" "MIT-SHM"];
        # # ^ getting BadValue crashes in wine/lutris games without this
        # ^ but it prevents OBS from capturing the screen (obviously), lol

        sddm.enable = true;
      };
      desktopManager.plasma5.enable = true;

      # Configure keymap in X11
      layout = "us,ru";
      xkbOptions = "grp:alt_shift_toggle,compose:rwin";
    };

    udev.packages = with pkgs; [
      # make solaar work
      logitech-udev-rules
      stlink
    ];

    pipewire = {
      enable = true;
      wireplumber.enable = true;

      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };

    dbus.enable = true;
    avahi = {
      enable = true;
      nssmdns = true;
    };

    keybase.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [
      24800 # barrier server
      24274 # my nearby-share project wip thing
    ];
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; } # KDE Connect
    ];
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; } # KDE Connect
    ];
  };

  system.stateVersion = "21.11";
}
