let
  necauqua = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9";
  offsite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P";
in
{
  "murmur-password.age".publicKeys = [ necauqua offsite ];
}
