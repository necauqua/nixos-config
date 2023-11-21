let
  him = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P";
in
{
  "murmur-password.age".publicKeys = [ him offsite ];
  "reposilite-password.age".publicKeys = [ him offsite ];
}
