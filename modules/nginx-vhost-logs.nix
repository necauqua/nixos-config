# Each nginx vhost writes its own access log, /var/log/nginx/<name>.access.log,
# so that the requests of one site can be told apart: the default `combined`
# format has no host. The logrotate rule of the nginx module
# (/var/log/nginx/*.log, weekly, 26 copies) rotates these files too.
#
# Only the server block of the vhost gets it. The plain http server block that
# `forceSSL` adds (the redirect to https) and the requests that no vhost takes
# still go to /var/log/nginx/access.log.
{ lib, ... }: {
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options.accessLog = lib.mkOption {
        type = lib.types.str;
        example = "/var/log/nginx/example.com.access.log";
        description = ''
          The arguments of the `access_log` directive of the vhost: a file
          (with an optional format), or `off`. The default is
          `/var/log/nginx/<name>.access.log`. A vhost with a regex name
          (`~...`) has no default, so it must set one.
        '';
      };

      config = {
        accessLog = lib.mkIf (!lib.hasPrefix "~" name)
          (lib.mkOptionDefault "/var/log/nginx/${name}.access.log");
        extraConfig = "access_log ${config.accessLog};";
      };
    }));
  };
}
