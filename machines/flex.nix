{ pkgs, modules, ... }: {

  imports = with modules; [
    configuration
    nvidia
  ];

  networking.hostName = "flex";

  nix.settings.max-jobs = 8;

  services.xserver = {
    # enable touchpad and also make it faster for the 4k display
    libinput = {
      enable = true;
      touchpad = {
        accelSpeed = "0.6";
        naturalScrolling = true;
      };
    };
    # some xrangr magic to fix touchpad display
    # along with xinput+unclutter to fix/prettify the touchscreen
    displayManager.setupCommands =
      let
        xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
      in
      ''
        ${xrandr} --newmode "1080x2160" 200.61 1080 1168 1288 1496 2160 2161 2164 2235 -hsync +vsync
        ${xrandr} --addmode HDMI-1-1 1080x2160
        ${pkgs.xorg.xinput}/bin/xinput --map-to-output "pointer:ELAN9008:00 04F3:2A46" eDP-1-1
        ${pkgs.unclutter-xfixes}/bin/unclutter --hide-on-touch -b
      '';
    screenSection = ''
      Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      Option "AllowIndirectGLXProtocol" "off"
      Option "TripleBuffer" "on"
    '';
  };

  # do the nvidia+intel laptop magic
  hardware.nvidia.prime = {
    sync.enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
  };

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/883dd157-68c7-4cca-aef8-f590a1872775";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/3632-E24C";
      fsType = "vfat";
    };
  };

  powerManagement.cpuFreqGovernor = "powersave";
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
}
