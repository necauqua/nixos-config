let
  secrets = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk secrets";
  main = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICX06Kpfqdi67PsxLTKPZaBeXhMp4rAV1ea2m3KDbuo+ main";
  flex = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwpx5Mz38iIi+r7EtbwON6T9OcmhgnJX7yFzXQlvq7f flex";
  home = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtulqkUsFZG7wQOzZmG0K/fQzRGC5J1u7NY0zOmyqF+ home";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P offsite";

  # the desktop machines run the borg job, offsite only serves the repo
  desktops = [ secrets main flex home ];
  offsite-only = [ secrets offsite ];
  # tg-alert is part of the shared config, so every machine needs tg-bot
  everywhere = [ secrets main flex home offsite ];
in
{
  "borg-key.age".publicKeys = desktops;
  "borg-pass.age".publicKeys = desktops;

  "cloudflare.age".publicKeys = offsite-only;
  "dkim-key.age".publicKeys = offsite-only;
  "elastic-key.age".publicKeys = offsite-only;
  "murmur-password.age".publicKeys = offsite-only;
  "pds-env.age".publicKeys = offsite-only;
  "reposilite-password.age".publicKeys = offsite-only;
  "smtp-server-sasl.age".publicKeys = offsite-only;
  "tg-bot.age".publicKeys = everywhere;
}
