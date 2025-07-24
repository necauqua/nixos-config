let
  him = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P";
  keys = [ him offsite ];
in
{
  "murmur-password.age".publicKeys = keys;
  "reposilite-password.age".publicKeys = keys;
  "smtp-server-sasl.age".publicKeys = keys;
  "cloudflare.age".publicKeys = keys;
  "homelab-proxy.age".publicKeys = keys;
  "homelab-cert.age".publicKeys = keys;
  "ldap-bind-password.age".publicKeys = keys;
  "ldap-anton-password.age".publicKeys = keys;
  "authelia-storage-key.age".publicKeys = keys;
  "authelia-jwt-key.age".publicKeys = keys;
  "authelia-smtp-password.age".publicKeys = keys;
  "catfeeder-secrets.age".publicKeys = keys;
  "elastic-key.age".publicKeys = keys;
}
