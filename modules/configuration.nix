{ config, pkgs, lib, flake-inputs, features, ... }: {

  imports = with features; [
    automount
    home-manager
    keyring
    overlays
    usbip
    nix-config
  ];

  nix = {
    settings = {
      trusted-users = [ "necauqua" ];
      auto-optimise-store = true;
    };
    registry = {
      # pin nixpkgs for speed
      nixpkgs.flake = flake-inputs.nixpkgs;
      # sudo nixos-rebuild switch --flake <main / local>
      # well, for the first setup the full git url would be needed ¯\_(ツ)_/¯
      main = {
        from = { id = "main"; type = "indirect"; };
        to = { type = "sourcehut"; owner = "~necauqua"; repo = "nixos-config"; };
        exact = false;
      };
      local = {
        from = { id = "local"; type = "indirect"; };
        to = { type = "path"; path = "/home/necauqua/projects/nixos-config"; };
        exact = false;
      };
    };
  };

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
    kernelModules = [ "v4l2loopback" ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';

    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    supportedFilesystems = [ "zfs" "ntfs" "btrfs" ];
  };

  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";

  time.timeZone = "Europe/Kiev";

  networking = {
    useDHCP = false;
    networkmanager.enable = true;
  };
  # shave off ~5 secs from boot, lol
  # we don't need this
  systemd.services.NetworkManager-wait-online.enable = false;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LANG = "en_US.UTF-8";
      LC_TIME = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
    };
  };

  hardware = {
    bluetooth.enable = true;
    graphics.enable32Bit = true;
  };

  users = {
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
    users.necauqua = {
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
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=lcd -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel";

      # no idea why is this not a default on an X11 systems
      QT_USE_PHYSICAL_DPI = "1";
    };

    etc = with pkgs; {
      # stable locations for all them javas
      jdk8.source = jdk8;
      jdk11.source = jdk11;
      jdk17.source = jdk17;

      # static lua lsp location for vscode
      lua-lsp.source = sumneko-lua-language-server;
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
    nix-ld = {
      enable = true;
      libraries = [ ];
    };
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
    displayManager.sddm.enable = true;
    xserver = {
      enable = true;
      dpi = 196;

      excludePackages = [ pkgs.xorg.xorgserver ];
      displayManager = {
        xserverBin = lib.mkForce "${pkgs.xserver-bug865}/bin/X";
        # xserverArgs = ["-extension" "MIT-SHM"];
        # # ^ getting BadValue crashes in wine/lutris games without this
        # ^ but it prevents OBS from capturing the screen (obviously), lol
      };
      desktopManager.plasma5.enable = true;

      # Configure keymap in X11
      xkb = {
        layout = "us,ru";
        options = "grp:alt_shift_toggle,compose:rwin";
      };
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
      nssmdns4 = true;
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
      5173 # svelte dev server
      9091 # transmission remote
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
