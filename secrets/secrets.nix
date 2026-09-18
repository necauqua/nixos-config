let
  secrets = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk secrets";
  main = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICX06Kpfqdi67PsxLTKPZaBeXhMp4rAV1ea2m3KDbuo+ main";
  flex = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwpx5Mz38iIi+r7EtbwON6T9OcmhgnJX7yFzXQlvq7f flex";
  home = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL40mSZlb9JLfZVt5pAH9K5CPtxHTpDH+PjMttVkkmSw home";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P offsite";

  # the desktop machines ran the borg job, offsite only serves the repo
  desktops = [ secrets main flex home ];
  offsite-only = [ secrets offsite ];
  # tg-alert is part of the shared config, so every machine needs tg-bot
  everywhere = [ secrets main flex home offsite ];
in
{
  "borg-key.age".publicKeys = desktops;
  "borg-pass.age".publicKeys = desktops;

  # main writes the backups and offsite serves and prunes the repository
  "restic.age".publicKeys = [ secrets main offsite ];
  "restic-htpasswd.age".publicKeys = offsite-only;

  # dns-01 challenges: necauq.ua on offsite, home.necauq.ua on home
  "cloudflare.age".publicKeys = [ secrets home offsite ];
  "dkim-key.age".publicKeys = offsite-only;
  "elastic-key.age".publicKeys = offsite-only;
  "murmur-password.age".publicKeys = offsite-only;
  "pds-env.age".publicKeys = offsite-only;
  "reposilite-password.age".publicKeys = offsite-only;
  "smtp-server-sasl.age".publicKeys = offsite-only;
  "tg-bot.age".publicKeys = everywhere;

  # core env file, plus the two noise keys of the core/agent pair on home
  "komodo.age".publicKeys = [ secrets home ];
  "komodo-core-key.age".publicKeys = [ secrets home ];
  "komodo-periphery-key.age".publicKeys = [ secrets home ];
}
