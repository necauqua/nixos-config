{ config, pkgs, lib, ... }:
let
  my-pkgs = import ./packages.nix { inherit pkgs; };
in {

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes repl-flake
      keep-outputs = true
      keep-derivations = true
    '';
    settings = {
      trusted-users = ["root" "necauqua"];
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

  i18n.defaultLocale = "en_US.UTF-8";

  # Enable sound
  sound.enable = true;
  hardware = {
    nvidia.modesetting.enable = true;
    opengl.driSupport32Bit = true;
    bluetooth.enable = true;
  };

  users = {
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
    users.necauqua = {
       isNormalUser = true;
       extraGroups = [ "wheel" "docker" "dialout" "adbusers" "networkmanager" "wireshark" ];
       hashedPassword = "$6$.fpv9TmqXoHSfmj/$ql9VtGHMsyJssreJY0lTINfQkYZSZZnDzAozje4R1jWiih92I.QlHbjmfPeRexBjEM4VfZseEo4R5id/OkK9a1";
    };
  };

  environment = {
    systemPackages = with pkgs; [
      fish
      helix
      polkit_gnome
      openssl
      zfs
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

      SSH_AUTH_SOCK="/run/user/1000/keyring/ssh";

      # huh. todo move all nvidia stuff to host-specific confs
      LIBVA_DRIVER_NAME="nvidia";
    };

    etc = with pkgs; {
      # stable locations for all them javas
      jdk8.source = jdk8;
      jdk11.source = jdk11;
      jdk16.source = adoptopenjdk-hotspot-bin-16;
      jdk17.source = jdk17;

      # also for awesome for lua LSP when editing the config
      awesome.source = my-pkgs.awesome-git;
      # and the LSP itself
      lua-lsp.source = sumneko-lua-language-server;
      # and rnix-lsp for vscode (for helix it's in the HM config)
      nix-lsp.source = rnix-lsp;
    };
  };

  fonts.fonts = with pkgs; [
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
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    # nix-ld.enable = true;
    seahorse.enable = true;
    steam.enable = true;
    wireshark.enable = true;
  };

  security = {
    pam.services.sddm.enableGnomeKeyring = true;
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
        xserverBin = lib.mkForce "${my-pkgs.xserver-bug865}/bin/X";
        xserverArgs = ["-extension" "MIT-SHM"];
        # ^ getting BadValue crashes in wine/lutris games without this
  
        sddm.enable = true;
        # autoLogin.enable = true;
        # autoLogin.user = "necauqua";
        defaultSession = "none+awesome";
       };
       windowManager.awesome = {
          enable = true;
          package = my-pkgs.awesome-git;
          luaModules = with pkgs.lua53Packages; [ luasocket tl ];
       };

      videoDrivers = [ "nvidia" ];

      # Configure keymap in X11
      layout = "us,ru";
      xkbOptions = "grp:alt_shift_toggle,compose:rwin";
    };

    # I have a G Pro Wireless now, make solaar work
    udev.packages = [ pkgs.logitech-udev-rules ];

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
      extraConfig = ''
        PubkeyAcceptedAlgorithms +ssh-rsa
        HostkeyAlgorithms +ssh-rsa
      '';
    };
    gnome.gnome-keyring.enable = true;
  
    dbus.enable = true;
    avahi = {
      enable = true;
      nssmdns = true;
    };
    greenclip.enable = true;

    openvpn.servers.vpn = {
      config = "config /home/necauqua/client.ovpn";
      autoStart = false;
    };
    
    keybase.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
    autoPrune.enable = true;
  };

  networking.firewall.allowedTCPPorts = [
    24800 # barrier server
  ];

  system.stateVersion = "21.11";
}
