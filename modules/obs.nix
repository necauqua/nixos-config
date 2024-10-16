{ pkgs, pkgs-stable, ... }: {
  environment.systemPackages = [
    (pkgs.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        obs-composite-blur
        obs-move-transition
        obs-pipewire-audio-capture
        obs-scale-to-sound
        obs-shaderfilter
        pkgs-stable.obs-studio-plugins.obs-transition-table
        obs-tuna
        obs-vkcapture
      ];
    })
  ];
}
