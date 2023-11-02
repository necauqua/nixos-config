{ config, ... }:
let
  package = config.boot.kernelPackages.usbip;
  port = 3240;
in
{
  boot = {
    extraModulePackages = [ package ];
    kernelModules = [ "usbip_host" ];
  };

  environment.systemPackages = [ package ];

  systemd.services.usbipd = {
    description = "USB/IP daemon";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${package}/bin/usbipd --tcp-port=${toString port}";
      Restart = "on-failure";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
