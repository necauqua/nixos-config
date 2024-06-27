{
  services.borgbackup.repos.offsite = {
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcjRPhZIYK5f7zv93AN+6klqfb6Tku12XIKTKsqcEQL"
    ];
    quota = "400G"; # just in case
  };
}
