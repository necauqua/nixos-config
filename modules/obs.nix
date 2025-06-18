{ pkgs, pkgs-stable, ... }: {

  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio.override { cudaSupport = true; };
    enableVirtualCamera = true;
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
  };
}
