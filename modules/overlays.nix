{...}:
let
  overlay = final: prev: {
    xserver-bug865 = prev.xorg.xorgserver.overrideAttrs (super: {
      pname = "xorgserver-bug865";
      patches = super.patches ++ [
        (prev.fetchpatch {
          name = "freedesktop-bug-865.patch";
          url = "https://aur.archlinux.org/cgit/aur.git/plain/freedesktop-bug-865.patch?h=xorg-server-bug865";
          sha256 = "sha256-ZZFjzc9QzrNL3pJLYYeanEEa1KoQstmkz42ryfOdmb4=";
        })
        (prev.fetchpatch {
          name = "0002-xephyr_Dont_check_for_SeatId_anymore.patch";
          url = "https://aur.archlinux.org/cgit/aur.git/plain/0002-xephyr_Dont_check_for_SeatId_anymore.patch?h=xorg-server-bug865";
          sha256 = "sha256-WPJEa2ltQwpKaREacuaVTZNpIZS9LSt6GgmbQaAYeNE=";
        })
      ];
    });
  };
in {
  nixpkgs.overlays = [ overlay ];
}