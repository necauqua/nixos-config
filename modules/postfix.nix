{ config, pkgs, ... }:
let
  domain = "necauq.ua";
in
{
  age.secrets.smtp-server-sasl = {
    file = ../secrets/smtp-server-sasl.age;
    mode = "770";
    owner = "postfix";
    group = "postfix";
  };

  services = {
    opendkim = {
      enable = true;
      user = "postfix";
      group = "postfix";
      domains = "csl:${domain}";
      selector = "main";
    };
    postfix = {
      enable = true;
      enableSubmission = true;
      enableSubmissions = true;
      relayPort = 587;

      hostname = domain;
      inherit domain;

      sslCert = "${config.security.acme.certs.${domain}.directory}/full.pem";
      sslKey = "${config.security.acme.certs.${domain}.directory}/key.pem";

      config =
        let
          # echo "$password" | ${pkgs.cyrus_sasl}/bin/saslpasswd2 -f sasl.db -u "$domain" -c -p "$username"
          # and then encrypt it into the agenix thing somehow
          sasl-conf-dir = pkgs.runCommand "sasl-conf.d" { } ''
            mkdir $out
            echo "pwcheck_method: auxprop" >> $out/smtpd.conf
            echo "auxprop_plugin: sasldb" >> $out/smtpd.conf
            echo "mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM" >> $out/smtpd.conf
            echo "sasldb_path: ${config.age.secrets.smtp-server-sasl.path}" >> $out/smtpd.conf
          '';
          milter = config.services.opendkim.socket;
        in
        {
          cyrus_sasl_config_path = "${sasl-conf-dir}";
          smtpd_sasl_auth_enable = true;
          smtpd_tls_auth_only = true;
          smtpd_sasl_local_domain = domain;

          smtpd_milters = milter;
          non_smtpd_milters = milter;
        };
    };

    nginx.virtualHosts."${domain}".enableACME = true;
  };

  security.acme.certs.${domain}.postRun = "systemctl restart postfix.service";
  users.users.postfix.extraGroups = [ "nginx" ];

  networking.firewall.allowedTCPPorts = [ config.services.postfix.relayPort ];
}
