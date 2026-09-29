let
  recovery = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO3KJORWfsKNYyiXrzV3cQSV/1T0Hs9xD/zV8hGGJ9kl";

  secrets = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk";
  main = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICX06Kpfqdi67PsxLTKPZaBeXhMp4rAV1ea2m3KDbuo+";
  flex = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwpx5Mz38iIi+r7EtbwON6T9OcmhgnJX7yFzXQlvq7f";
  home = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL40mSZlb9JLfZVt5pAH9K5CPtxHTpDH+PjMttVkkmSw";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P";

  keys = k: [ recovery secrets ] ++ k;

  # the desktop machines ran the borg job, offsite only serves the repo
  desktops = keys [ main flex home ];
  offsite-only = keys [ offsite ];

  # tg-alert is part of the shared config, so every machine needs tg-bot
  everywhere = keys [ main flex home offsite ];
in
{
  "borg-key.age".publicKeys = desktops;
  "borg-pass.age".publicKeys = desktops;

  # main writes the backups and offsite serves and prunes the repository
  "restic.age".publicKeys = keys [ main offsite ];
  "restic-htpasswd.age".publicKeys = offsite-only;

  # dns-01 challenges: necauq.ua on offsite, home.necauq.ua on home
  "cloudflare.age".publicKeys = keys [ home offsite ];
  "dkim-key.age".publicKeys = offsite-only;
  "elastic-key.age".publicKeys = offsite-only;
  "murmur-password.age".publicKeys = offsite-only;
  "pds-env.age".publicKeys = offsite-only;
  "reposilite-password.age".publicKeys = offsite-only;
  "smtp-server-sasl.age".publicKeys = offsite-only;
  "tg-bot.age".publicKeys = everywhere;

  # ssh key that the git server on home pushes its mirrors with
  "git-mirror.age".publicKeys = keys [ home ];

  # node key of the radicle node on home, which is also the key that signs the
  # refs it mirrors
  "radicle-key.age".publicKeys = keys [ home ];

  # core env file, plus the two noise keys of the core/agent pair on home
  "komodo.age".publicKeys = keys [ home ];
  "komodo-core-key.age".publicKeys = keys [ home ];
  "komodo-periphery-key.age".publicKeys = keys [ home ];
}
