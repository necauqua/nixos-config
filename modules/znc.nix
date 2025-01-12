{ config, lib, pkgs, ... }:
let
  domain = "necauq.ua";
  zncMod =
    { src
    , version
    , module_name
    , buildInputs ? [ ]
    }: with pkgs;
    stdenv.mkDerivation {
      inherit src version;
      pname = "znc-${module_name}";
      buildPhase = "${znc}/bin/znc-buildmod ${module_name}.cpp";
      installPhase = "install -D ${module_name}.so $out/lib/znc/${module_name}.so";
      buildInputs = znc.buildInputs ++ buildInputs;
      meta.platforms = lib.platforms.unix;
      passthru.module_name = module_name;
    };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      znc = prev.znc.overrideAttrs (super: {
        buildInputs = super.buildInputs ++ [ final.pcre-cpp ];
      });
    })
  ];
  services.znc = {
    enable = true;
    mutable = false;
    useLegacyConfig = false;
    openFirewall = true;

    modulePackages = with pkgs; [
      zncModules.backlog
      zncModules.clientbuffer
      zncModules.playback
      (zncMod {
        module_name = "highlightattach";
        version = "unstable-2017-06-15";
        src =
          fetchFromGitHub {
            owner = "sk89q";
            repo = "znc-modules";
            rev = "b88b2031be23028b0c00f6dcfd06ac16778ad63a";
            sha256 = "sha256-IYmAiGegN1VJCW/ImYcZyaByWvS1jG6ZjcG3U2/I73g";
          };
        buildInputs = [ pkgs.pcre-cpp ];
      })
    ];

    config = {
      LoadModule = [ "log" "backlog" "identfile" ];
      User.necauqua = {
        LoadModule = [
          "alias"
          "clientbuffer"
          "highlightattach"
          "playback"
        ];
        Ident = "him";
        RealName = "Anton Bulakh";
        Admin = true;
        AutoClearChanBuffer = false;
        AutoClearQueryBuffer = false;
        # eh, whatever
        Pass.password = {
          Method = "sha256";
          Hash = "01599ce86a49786baa52ecabd47c8c198e88a0758f61c63926da8bc359d6f6e1";
          Salt = "WC3i5T8tYCotkxLWYW-a";
        };
        Network.libera = {
          Server = "irc.libera.chat +6697";
          LoadModule = [
            "route_replies"
            "sasl"
            "savebuff"
            "simple_away"
          ];
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
      cfg = pkgs.writeText
        "oidentd.conf"
        ''
          user "${config.services.znc.user}" {
              default {
                  allow spoof
                  allow spoof_all
              }
          }
        '';
      final = pkgs.runCommand
        "oidentd.conf"
        { }
        ''
          cat ${pkgs.oidentd}/etc/oidentd.conf ${cfg} > $out
        '';
    in
    lib.mkForce
      "${pkgs.oidentd}/sbin/oidentd -u oidentd -g nogroup -C ${final}";

  # make znc home "world-executable" for oidentd to be able to read
  # the .oidentd.conf that identfile should make there
  users.users.${config.services.znc.user}.homeMode = "711";
  networking.firewall.allowedTCPPorts = [ 113 ];

  services.nginx.virtualHosts.${domain}.enableACME = true;

  security.acme.certs.${domain}.postRun =
    "cat {key,fullchain}.pem > ${config.services.znc.dataDir}/znc.pem";
}
