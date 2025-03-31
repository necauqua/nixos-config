{ config, pkgs, features, ... }: {

  imports = with features; [
    automount
    home-manager
    keyring
    overlays
    usbip
    nix-flakes
    nix-config
    tailscale
    gnome
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    # consoleLogLevel = 0;
    # initrd.verbose = false;
    # kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      # "udev.log_priority=3"
      # "quiet"
      # fix keychron fn keys
      "hid_apple.fnmode=0"
      # enable cp --reflink on zfs
      "zfs.zfs_bclone_enabled=1"
    ];
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback.out
    ];
    kernelModules = [ "v4l2loopback" ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';
    supportedFilesystems = [ "zfs" "ntfs" "btrfs" ];
  };

  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
    packages = [ pkgs.terminus_font ];
  };

  time.timeZone = "Europe/Kiev";

  networking = {
    useDHCP = false;
    networkmanager.enable = true;
  };
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
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgGnuv1hYWQC1GJQdTqcZhM1qGbUNXx5GcRLif1Wrmn work"
      ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      fish
      gparted
      helix
      openssl

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
      _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2.5 -Dawt.useSystemAAFontSettings=lcd -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel";
    };

    etc = with pkgs; {
      # stable locations for all them javas
      jdk8.source = jdk8;
      jdk11.source = jdk11;
      jdk17.source = jdk17;
      jdk21.source = jdk21;

      # static lsp locations for vscode
      lua-lsp.source = sumneko-lua-language-server;
      nix-lsp.source = nil;
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
    nerd-fonts.jetbrains-mono

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
  ];
  programs = {
    adb.enable = true;
    dconf.enable = true;
    fish.enable = true;
    less.envVariables.LESS = "FRX --mouse";
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
      Defaults lecture = never
    '';
    rtkit.enable = true;
  };

  services = {

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
