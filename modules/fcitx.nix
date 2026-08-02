{ ... }: {
  # fcitx5 as the input method framework. On Wayland (niri) it plugs into the
  # text-input-v3 protocol, which lets it intercept the compose key and drive
  # Unicode input for apps that would otherwise handle input themselves.
  #
  # Two reasons it's here:
  #  - Chromium/Electron ignore custom ~/.XCompose (they use their own compose
  #    table). Routing their input through fcitx5 makes fcitx5 do the compose
  #    using ~/.XCompose instead, so custom sequences finally work.
  #  - the fcitx5 core "unicode" addon gives a searchable Unicode picker (see
  #    the home profile for the Ctrl+Shift+U trigger binding).
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
  };
}
