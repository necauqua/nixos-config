{ pkgs, flake-inputs, features, ... }:
let
  # wpa_supplicant reads the PSKs from here, the `wifi` script below writes them
  secrets-file = "/run/wifi-psk";
in
{

  imports = with features; [
    "${flake-inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    nix-config
  ];

  boot.kernelParams = [ "hid_apple.fnmode=0" ];

  environment = {
    systemPackages = with pkgs; [
      fish
      helix
      zfs
      wpa_supplicant

      # the ISO knows which networks to join, but not their passphrase - this
      # asks for it, derives the PSK of each band and brings the link up
      (writeShellScriptBin "wifi" ''
        set -eu
        read -rsp 'Wifi passphrase: ' pass
        echo
        umask 077
        derive() {
          ${wpa_supplicant}/bin/wpa_passphrase "$1" "$pass" |
            awk -F= '/^[[:space:]]*psk=/ { print $2 }'
        }
        {
          echo "psk_anton=$(derive anton)"
          echo "psk_anton_5g=$(derive anton-5g)"
        } >${secrets-file}
        systemctl restart wpa_supplicant
      '')
    ];
    variables.EDITOR = "${pkgs.helix}/bin/hx";
    shells = [ pkgs.bashInteractive pkgs.fish ];
  };

  programs.fish.enable = true;

  networking.wireless = {
    enable = true;
    secretsFile = secrets-file;
    networks = {
      anton.pskRaw = "ext:psk_anton";
      anton-5g.pskRaw = "ext:psk_anton_5g";
    };
  };

  # wpa_supplicant bind-mounts the secrets file, so it must exist before the
  # service starts, even while it is still empty
  systemd.tmpfiles.rules = [ "f ${secrets-file} 0600 root root" ];

  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
  users = {
    defaultUserShell = pkgs.fish;
    users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
    ];
  };

  # build it faster
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
