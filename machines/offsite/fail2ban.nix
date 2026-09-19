{ pkgs, ... }: {
  # mostly stolen from
  # https://dataswamp.org/~solene/2022-10-02-nixos-fail2ban.html
  # for now
  services.fail2ban = {
    enable = true;
    extraPackages = [ pkgs.ipset ];
    banaction = "iptables-ipset-proto6-allports";

    jails = {
      nginx-spam.settings = {
        enabled = true;
        filter = "nginx-bruteforce";
        logpath = "/var/log/nginx/access.log";
        backend = "auto";
        maxretry = 6;
        findtime = 600;
      };
      postfix-bruteforce.settings = {
        enabled = true;
        filter = "postfix-bruteforce";
        findtime = 600;
        maxretry = 3;
      };
    };
  };

  environment.etc = {
    "fail2ban/filter.d/postfix-bruteforce.conf".text = ''
      [Definition]
      failregex = warning: [\w\.\-]+\[<HOST>\]: SASL LOGIN authentication failed.*$
      journalmatch = _SYSTEMD_UNIT=postfix.service
    '';
    "fail2ban/filter.d/nginx-bruteforce.conf".text = ''
      [Definition]
      failregex = ^<HOST>.*GET.*(matrix/server|\.php|admin|wp\-).* HTTP/\d.\d\" 404.*$
    '';
  };
}
