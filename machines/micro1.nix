{ features, ... }: {

  imports = with features; [
    nix-flakes
    nix-config
    oci-micro
    komodo
  ];

  networking.hostName = "micro1";
}
