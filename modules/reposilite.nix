{ config, ... }:
let
  port = 7000;
in
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.reposilite = {
      image = "dzikoysk/reposilite@sha256:379fff2c62a1580362aae9abaeebf58bea5ad0faf025e4519e460fe696c643c0";
      ports = [ "127.0.0.1:${builtins.toString port}:8080" ];
      volumes = [ "/root/reposilite-data:/app/data" ];
    };
  };

  age.secrets.reposilite-password = {
    file = ../secrets/reposilite-password.age;
    mode = "770";
    owner = "nginx";
    group = "nginx";
  };

  services.nginx.virtualHosts."maven.necauqua.dev" = {
    forceSSL = true;
    enableACME = true;
    locations =
      let
        common = {
          proxyPass = "http://127.0.0.1:${builtins.toString port}";
          proxyWebsockets = true;
          extraConfig = "proxy_pass_header Authorization;";
        };
      in
      {
        "/api/" = common;
        "/assets/" = common;
        "/releases/" = common;
        "= /" = {
          root = "/var/www/maven.necauqua.dev";
        };
        "= /index.html" = {
          root = "/var/www/maven.necauqua.dev";
        };
        "= /favicon.png" = {
          root = "/var/www/necauqua.dev";
        };
        "/ui" = {
          proxyPass = "http://127.0.0.1:${builtins.toString port}/";
          recommendedProxySettings = true;
          basicAuthFile = config.age.secrets.reposilite-password.path;
        };
        "/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString port}/releases/";
          recommendedProxySettings = true;
          extraConfig = "proxy_pass_header Authorization;";
        };
      };
  };
}
