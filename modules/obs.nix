{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        obs-composite-blur
        obs-move-transition
        obs-pipewire-audio-capture
        obs-scale-to-sound
        obs-shaderfilter
        obs-transition-table
        obs-tuna
        obs-vkcapture
      ];
    })
  ];
}
