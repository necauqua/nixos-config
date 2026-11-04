{ pkgs, ... }: {
  hardware.rtl-sdr = {
    enable = true;
    package = pkgs.rtl-sdr-blog;
  };
  users.users.necauqua.extraGroups = [ "plugdev" ];

  environment.systemPackages = with pkgs; [
    sdrpp
    sdrangel
    rtl_433
    satdump
    readsb
    multimon-ng
    inspectrum
    urh
  ];
}
