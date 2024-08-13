{ config, pkgs, ... }:
let
  cfg = config.services.authelia.instances.main;
  secrets = config.age.secrets;
in
{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ cfg.user ];
    ensureUsers = [
      { name = cfg.user; ensureDBOwnership = true; }
    ];
  };

  age.secrets = {
    authelia-storage-key = {
      file = ../secrets/authelia-storage-key.age;
      owner = cfg.user;
    };
    authelia-jwt-key = {
      file = ../secrets/authelia-jwt-key.age;
      owner = cfg.user;
    };
    authelia-smtp-password = {
      file = ../secrets/authelia-smtp-password.age;
      owner = cfg.user;
    };
    ldap-bind-password.mode = "440";
  };

  users.users.${cfg.user}.extraGroups = [ config.services.portunus.group ];

  services.authelia.instances.main = {
    enable = true;
    secrets = {
      jwtSecretFile = secrets.authelia-jwt-key.path;
      storageEncryptionKeyFile = secrets.authelia-storage-key.path;
    };
    environmentVariables = {
      AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = secrets.ldap-bind-password.path;
      AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = secrets.authelia-smtp-password.path;
    };
    settings = {
      theme = "auto";
      authentication_backend = {
        password_reset.disable = false;
        ldap = {
          implementation = "custom";
          address = "ldaps://sso.necauq.ua";
          base_dn = "dc=necauq,dc=ua";
          additional_users_dn = "ou=users";
          users_filter = "(&({username_attribute}={input})(objectClass=person))";
          additional_groups_dn = "ou=groups";
          groups_filter = "(member={dn})";
          user = "uid=bind,ou=users,dc=necauq,dc=ua";
          attributes = {
            display_name = "displayName";
            mail = "mail";
            username = "uid";
            group_name = "cn";
          };
        };
      };
      access_control.default_policy = "one_factor";
      storage.postgres = {
        address = "unix:///run/postgresql";
        database = cfg.user;
        username = cfg.user;
        password = cfg.user; # we don't need a password here, but authelia complains
      };
      session.cookies = [
        {
          domain = "necauq.ua";
          authelia_url = "https://auth.necauq.ua";
        }
      ];
      notifier.smtp = {
        address = "smtp://necauq.ua:${toString config.services.postfix.relayPort}";
        username = "matrix-noreply";
        sender = "authelia@necauq.ua";
      };
    };
  };

  services.nginx.virtualHosts."auth.necauq.ua" = {
    onlySSL = true;
    useACMEHost = "necauq.ua";
    locations."/".proxyPass = "http://127.0.0.1:9091";
  };

  systemd.services.authelia-main = {
    # Authelia requires LDAP and PostgreSQL to be running
    bindsTo = [
      "portunus.service"
      "postgresql.service"
    ];
  };

  nixpkgs.overlays = [
    (final: prev: {
      authelia-location = pkgs.writeText "authelia-location.conf" ''
        set $upstream_authelia http://127.0.0.1:9091/api/authz/auth-request;

        ## Virtual endpoint created by nginx to forward auth requests.
        location /internal/authelia/authz {
            ## Essential Proxy Configuration
            internal;
            proxy_pass $upstream_authelia;

            ## Headers
            ## The headers starting with X-* are required.
            proxy_set_header X-Original-Method $request_method;
            proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header Content-Length "";
            proxy_set_header Connection "";

            ## Basic Proxy Configuration
            proxy_pass_request_body off;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503; # Timeout if the real server is dead
            proxy_redirect http:// $scheme://;
            proxy_http_version 1.1;
            proxy_cache_bypass $cookie_session;
            proxy_no_cache $cookie_session;
            proxy_buffers 4 32k;
            client_body_buffer_size 128k;

            ## Advanced Proxy Configuration
            send_timeout 5m;
            proxy_read_timeout 240;
            proxy_send_timeout 240;
            proxy_connect_timeout 240;
        }
      '';
      authelia-authrequest = pkgs.writeText "authelia-authrequest.conf" ''
        ## Send a subrequest to Authelia to verify if the user is authenticated and has permission to access the resource.
        auth_request /internal/authelia/authz;

        ## Save the upstream metadata response headers from Authelia to variables.
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;

        ## Inject the metadata response headers from the variables into the request made to the backend.
        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Email $email;
        proxy_set_header Remote-Name $name;

        ## Configure the redirection when the authz failure occurs.
        ## This method uses the session cookies configuration's authelia_url
        ## value to determine the redirection URL here. It's much simpler and compatible with the mutli-cookie domain easily.

        ## Set the $redirection_url to the Location header of the response to the Authz endpoint.
        auth_request_set $redirection_url $upstream_http_location;

        ## When there is a 401 response code from the authz endpoint redirect to the $redirection_url.
        error_page 401 =302 $redirection_url;
      '';
    })
  ];
}
