let
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+3CzNhhWDQppHT1of+a8QCzlgQidlgUWEBMYUJnrfk secrets"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICX06Kpfqdi67PsxLTKPZaBeXhMp4rAV1ea2m3KDbuo+ main"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwpx5Mz38iIi+r7EtbwON6T9OcmhgnJX7yFzXQlvq7f flex"
  ];
in
{
  borg-key.publicKeys = keys;
  borg-pass.publicKeys = keys;
  selfsig-key.publicKeys = keys;
  selfsig-cert.publicKeys = keys;
}
