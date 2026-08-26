let
  him = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P";
  keys = [ him offsite ];
in
{
  "murmur-password.age".publicKeys = keys;
  "reposilite-password.age".publicKeys = keys;
  "smtp-server-sasl.age".publicKeys = keys;
  "dkim-key.age".publicKeys = keys;
  "cloudflare.age".publicKeys = keys;
  "elastic-key.age".publicKeys = keys;
  "pds-env.age".publicKeys = keys;
  "tg-bot.age".publicKeys = keys;
}
