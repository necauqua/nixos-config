{ config, pkgs, ... }:
let
  domain = "necauq.ua";
  cfg = config.services.postfix;
in
{
  age.secrets.smtp-server-sasl = {
    file = ../secrets/smtp-server-sasl.age;
    owner = cfg.user;
  };

  age.secrets.dkim-key = {
    file = ../secrets/dkim-key.age;
    owner = config.services.rspamd.user;
  };

  services = {
    rspamd = {
      enable = true;
      locals = {
        "dkim_signing.conf".text = ''
          domain {
            ${domain} {
              path = "${config.age.secrets.dkim-key.path}";
              selector = "main";
            }
          }
        '';
        # just opendkim replacement for now, will configure filters later ig
        "actions.conf".text = ''
          reject = null;
          add_header = null;
          greylist = null;
        '';
      };
    };
    postfix = {
      enable = true;
      enableSubmission = true;
      enableSubmissions = true;

      settings.main =
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
        in
        {
          relayhost = [ "${domain}:587" ];
          mydestination = [ "localhost" ];
          myhostname = domain;
          mydomain = domain;
          # ^ we're send-only, so send stuff to necauq.ua externally to be received by what's configured in dns
          cyrus_sasl_config_path = "${sasl-conf-dir}";
          smtpd_sasl_auth_enable = true;
          smtpd_tls_auth_only = true;
          smtpd_sasl_local_domain = domain;

          smtpd_milters = "unix:/run/rspamd/postfix.sock";
          non_smtpd_milters = "unix:/run/rspamd/postfix.sock";
          milter_protocol = "6";
          milter_mail_macros = "i {mail_addr} {client_addr} {client_name} {auth_authen}";

          smtpd_tls_chain_files = [
            "${config.security.acme.certs.${domain}.directory}/key.pem"
            "${config.security.acme.certs.${domain}.directory}/cert.pem"
          ];
        };
    };

    nginx.virtualHosts.${domain}.enableACME = true;
  };

  # systemd.services.rspamd.serviceConfig.SupplementaryGroups = [ cfg.group ];

  security.acme.certs.${domain}.postRun = "systemctl restart postfix.service";
  users.users.postfix.extraGroups = [ config.services.nginx.group ];

  networking.firewall.allowedTCPPorts = [ 587 ];
}
