{ config, lib, pkgs, modulesPath, features, flake-inputs, ... }: {

  imports = with features; [
    (modulesPath + "/profiles/qemu-guest.nix")

    nix-flakes

    acme
    komodo
    rsync-restricted-group
    ssh
    tg-alert

    ./fail2ban.nix
    ./goatcounter.nix
    ./matrix.nix
    ./murmur.nix
    ./nas-mount.nix
    ./nginx.nix
    ./ntfy.nix
    ./pds.nix
    ./pgp.nix
    ./postfix.nix
    ./reposilite.nix
    ./restic-server.nix
    ./soju
    ./stupid-fichub-api.nix
    ./tangled.nix
    ./twitch-archiver.nix
    ./wireguard.nix
    ./websites
  ];

  services.postgresql = {
    # every module that needs it sets `enable = true` itself

    # pin the major version
    package = pkgs.postgresql_16;
    # setup peer auth
    authentication = lib.mkOverride 10 ''
      local all all trust
    '';
  };

  boot = {
    tmp.cleanOnBoot = true;
    loader.grub.device = "/dev/disk/by-id/wwn-0x50014ee059afcbb6";
    initrd = {
      availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
      kernelModules = [ "nvme" ];
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/49648b41-bb27-4a47-b874-235d61f417f3";
      fsType = "ext4";
    };
    "/storage" = {
      device = "/dev/disk/by-uuid/ec50ec1f-538c-4561-8c4c-989c1c70233c";
      fsType = "ext4";
    };
  };

  security.acme.certs."necauq.ua" = {
    dnsProvider = "cloudflare";
    webroot = lib.mkForce null; # override all the nginx enableACME lines
    environmentFile = config.age.secrets.cloudflare.path;
    extraDomainNames = [ "*.necauq.ua" ];
  };

  networking = {
    hostName = "offsite";
    domain = "necauq.ua";
    defaultGateway6 = {
      address = "2a00:7a60:0001:0c00::1";
      interface = "enp3s0";
    };
    interfaces.enp3s0.ipv6.addresses = [{
      address = "2a00:7a60:1:d62::1";
      prefixLength = 64;
    }];
  };

  nix.registry.nixos = {
    from = { id = "nixos"; type = "indirect"; };
    flake = flake-inputs.nixpkgs;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # frozen: restic-server.nix took over, these archives only stay
  # readable until the restic history is long enough to drop them
  services.borgbackup.repos.offsite = {
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcjRPhZIYK5f7zv93AN+6klqfb6Tku12XIKTKsqcEQL"
    ];
    quota = "400G"; # just in case
    path = "/storage/borgbackup";
  };

  # #KyivNotKiev
  time.timeZone = "Europe/Kiev";

  programs.fish.enable = true;

  users = {
    users.root.shell = pkgs.fish;
    mutableUsers = false;
  };

  environment.systemPackages = [
    pkgs.helix
  ];

  system.stateVersion = "23.11";
}
