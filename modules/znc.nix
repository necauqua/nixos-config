{ config, lib, pkgs, ... }:
let
  domain = "necauq.ua";
in
{
  services.znc = {
    enable = true;
    mutable = false;
    useLegacyConfig = false;
    openFirewall = true;

    modulePackages = [
      pkgs.zncModules.backlog
    ];

    config = {
      LoadModule = [ "log" "backlog" "identfile" ];
      User.necauqua = {
        Ident = "him";
        RealName = "Anton Bulakh";
        Admin = true;
        # eh, whatever
        Pass.password = {
          Method = "sha256";
          Hash = "01599ce86a49786baa52ecabd47c8c198e88a0758f61c63926da8bc359d6f6e1";
          Salt = "WC3i5T8tYCotkxLWYW-a";
        };
        Network.libera = {
          Server = "irc.libera.chat +6697";
          LoadModule = [ "sasl" "simple_away" ];
        };
      };
    };
  };

  services.oidentd.enable = true;

  # because it does not read the config from /etc,
  # it was reading it from the derivation
  # pfew, that was fun times debugging this bs :)
  systemd.services.oidentd.script =
    let
      cfg = pkgs.writeText "oidentd.conf" ''
        user "${config.services.znc.user}" {
            default {
                allow spoof
                allow spoof_all
            }
        }
      '';
      final = pkgs.runCommand "oidentd.conf" { } ''
        cat ${pkgs.oidentd}/etc/oidentd.conf ${cfg} > $out
      '';
    in
    lib.mkForce "${pkgs.oidentd}/sbin/oidentd -u oidentd -g nogroup -C ${final}";

  # make znc home "world-executable" for oidentd to be able to read
  # the .oidentd.conf that identfile should make there
  users.users.${config.services.znc.user}.homeMode = "711";
  networking.firewall.allowedTCPPorts = [ 113 ];

  services.nginx.virtualHosts.${domain}.enableACME = true;

  security.acme.certs.${domain}.postRun =
    "cat {key,fullchain}.pem > ${config.services.znc.dataDir}/znc.pem";
}
