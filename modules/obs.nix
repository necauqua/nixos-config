{ pkgs, pkgs-stable, ... }:
let
  obs-localvocal-pkg =
    { stdenv
    , lib
    , fetchurl
    , dpkg
    , autoPatchelfHook
    , makeWrapper
    , obs-studio
    , curl
    , openssl
    , icu
    , libGL
    , openblas
    , qt6
    , icu70
    , cudaPackages ? null
    , withCuda ? false
    }:

    stdenv.mkDerivation rec {
      pname = "obs-localvocal";
      version = "0.6.2";

      src = fetchurl {
        url = "https://github.com/royshil/obs-localvocal/releases/download/${version}/obs-localvocal-${version}-x86_64-linux-gnu-${if withCuda then "nvidia" else "generic"}.deb";
        hash =
          if withCuda
          then "sha256-CiHyclHaXOm3Jq0oT8w/WQgAKo3xmg0Xyyi0VxSykH8="
          else "sha256-a0h9ZAuZP5WTvXbncMXDrLhND3MZYLJbswYb6cq+WM8=";
      };

      nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];

      buildInputs = [
        obs-studio
        curl
        openssl
        icu
        libGL
        openblas
        qt6.qtbase
        qt6.qtsvg
        icu70
        stdenv.cc.cc.lib
      ] ++ lib.optionals withCuda [
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
      ];

      dontWrapQtApps = true;
      autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];

      unpackPhase = ''
        runHook preUnpack
        dpkg-deb -x $src .
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/obs-plugins $out/share
        cp -r usr/lib/x86_64-linux-gnu/obs-plugins/* $out/lib/obs-plugins/
        cp -r usr/share/obs $out/share/
        runHook postInstall
      '';

      meta = with lib; {
        description = "OBS plugin for local speech recognition and captioning using AI";
        homepage = "https://github.com/royshil/obs-localvocal";
        license = licenses.gpl2Only;
        platforms = [ "x86_64-linux" ];
        maintainers = [ ];
      };
    };

  obs-localvocal = pkgs.callPackage obs-localvocal-pkg { withCuda = true; };
in
{
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
      obs-localvocal
    ];
  };
}
