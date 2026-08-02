{ config, lib, ... }:
lib.mkIf (!config.headless) {
  # fcitx5-unicode addon: searchable Unicode picker. Rebind its trigger from the
  # default Ctrl+Alt+Shift+U to Ctrl+Shift+U. Type part of a character's name to
  # search, not just a hex codepoint.
  xdg.configFile."fcitx5/conf/unicode.conf".text = ''
    TriggerKey=Control+Shift+U
    DirectUnicodeMode=
  '';

  # Chromium reads flags from this file (nixpkgs wrapper). --enable-wayland-ime
  # is what makes it actually talk to fcitx5 over the Wayland text-input
  # protocol; NIXOS_OZONE_WL already forces the Wayland/ozone backend.
  xdg.configFile."chromium-flags.conf".text = ''
    --enable-wayland-ime
  '';

  # Best-effort equivalent for generic Electron apps that honor this file.
  # Apps that don't read it need the flag passed on their command line, e.g.
  # `--enable-wayland-ime` (and `--ozone-platform-hint=auto`).
  xdg.configFile."electron-flags.conf".text = ''
    --enable-wayland-ime
  '';
}
