{ pkgs, lib, features, ... }: {

  imports = with features; [
    configuration
    nvidia
    hyprland
  ];

  networking = { hostName = "flex"; hostId = "ea6a1608"; };

  nix.settings.max-jobs = 8;

  services = {
    # enable touchpad and also make it faster for the 4k display
    libinput = {
      enable = true;
      touchpad = {
        accelSpeed = "0.6";
        naturalScrolling = true;
      };
    };

    xserver = {
      # some xrangr magic to fix touchpad display
      # along with xinput+unclutter to fix/prettify the touchscreen
      displayManager.setupCommands =
        let
          xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
        in
        ''
          ${xrandr} --newmode "1080x2160" 200.61 1080 1168 1288 1496 2160 2161 2164 2235 -hsync +vsync
          ${xrandr} --addmode HDMI-1 1080x2160
          echo on > /sys/kernel/debug/dri/1/HDMI-A-1/force
          echo off > /sys/kernel/debug/dri/1/HDMI-A-1/force
          ${pkgs.xorg.xinput}/bin/xinput --map-to-output "pointer:ELAN9008:00 04F3:2A46" eDP-1
          ${pkgs.unclutter-xfixes}/bin/unclutter --hide-on-touch -b
        '';
      screenSection = ''
        Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
        Option "AllowIndirectGLXProtocol" "off"
        Option "TripleBuffer" "on"
      '';

      # flex has no rwin
      xkb.options = "grp:alt_shift_toggle,compose:rctrl";
    };
  };

  systemd.services.disable-touchpad-screen = {
    wantedBy = [ "halt.target" "reboot.target" "poweroff.target" ];
    before = [ "halt.target" "reboot.target" "poweroff.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "disable-touchpad-screen" ''
        xrandr --output HDMI-1 --off
      '';
    };
  };

  # do the nvidia+intel laptop magic
  hardware.nvidia = {
    prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
    };
    open = false;
  };

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # LIBVA_DRIVER_NAME=iHD
    intel-vaapi-driver # LIBVA_DRIVER_NAME=i965
    libvdpau-va-gl
  ];
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    GSK_RENDERER = "ngl";
  };

  boot = {
    loader.systemd-boot.consoleMode = "max";
    kernelParams = [ "video=HDMI-A-1:d" ];

    kernelModules = [ "kvm-intel" ];

    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "sdhci_pci" ];

      luks.devices.root = {
        device = "/dev/disk/by-label/root";
        preLVM = true;
      };

      # zfs is so completely stupid, apparently they made it so
      # you cannot rollback to an older snapshot without deleting
      # all the newer ones.. FOR SOME REASON??..?
      #
      # And no, there is NO *ACTUAL* REASON for it to be required, only
      # some semantics about how the rollback does not roll back just the
      # file state but the entire dataset and that includes latter snapshots..
      #
      # Haven't figured out a clean way to make snapshots of old roots here,
      # clone promotion does not do the trick (and aint the clones just as
      # useless because of a stupid implicit semantic dependencies lol)
      postDeviceCommands = lib.mkAfter ''
        zfs rollback -r rpool/root@blank
      '';
    };
  };

  fileSystems =
    let
      persist-bind-mounts = {
        "/var/lib/bluetooth" = "bluetooth";
        "/var/lib/NetworkManager" = "network-manager/lib";
        "/etc/NetworkManager/system-connections" = "network-manager/connections";
        "/var/lib/systemd/coredump" = "systemd/coredump";
        "/var/lib/systemd/backlight" = "systemd/backlight";
      };
      extras = lib.mapAttrs
        (_: name: {
          device = "/saved/${name}";
          options = [ "bind" "noauto" "x-systemd.automount" ];
        })
        persist-bind-mounts;
    in
    {
      "/" = { device = "rpool/root"; fsType = "zfs"; };
      "/nix" = { device = "rpool/nix"; fsType = "zfs"; };
      "/var/log" = { device = "rpool/var/log"; fsType = "zfs"; };
      "/saved" = { device = "rpool/root/saved"; fsType = "zfs"; neededForBoot = true; };
      "/boot" = { label = "boot"; fsType = "vfat"; };
    } // extras;

  environment.etc."machine-id".source = "/saved/machine-id";

  powerManagement.cpuFreqGovernor = "powersave";
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  programs.light = {
    enable = true;
    brightnessKeys = {
      enable = true;
      step = 5;
    };
  };
}
