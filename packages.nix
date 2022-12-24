{ pkgs }: {
  xserver-bug865 = pkgs.xorg.xorgserver.overrideAttrs (super: {
    pname = "xorgserver-bug865";
    patches = super.patches ++ [
      (pkgs.fetchpatch {
        name = "freedesktop-bug-865.patch";
        url = "https://aur.archlinux.org/cgit/aur.git/plain/freedesktop-bug-865.patch?h=xorg-server-bug865";
        sha256 = "sha256-ZZFjzc9QzrNL3pJLYYeanEEa1KoQstmkz42ryfOdmb4=";
      })
      (pkgs.fetchpatch {
        name = "0002-xephyr_Dont_check_for_SeatId_anymore.patch";
        url = "https://aur.archlinux.org/cgit/aur.git/plain/0002-xephyr_Dont_check_for_SeatId_anymore.patch?h=xorg-server-bug865";
        sha256 = "sha256-WPJEa2ltQwpKaREacuaVTZNpIZS9LSt6GgmbQaAYeNE=";
      })
    ]; 
  });
  awesome-git = (pkgs.awesome.override { lua = pkgs.lua5_3; gtk3Support = true; } )
    .overrideAttrs (super: {
      name = "awesome-git";
      src = pkgs.fetchFromGitHub {
        owner = "awesomewm";
        repo = "awesome";
        rev = "b7bac1dc761f7e231355e76351500a97b27b6803";
        sha256 = "sha256-SxydaQScu0kvBn3VOnT29/Sji0Y+7my+tO46mpMggAQ=";
      };
      # disable upstream patches since we're on git bleeding edge
      # and they are already there since forever ago
      patches = [];
      # deps used by my awesome setup through lgi
      buildInputs = super.buildInputs ++ (with pkgs; [ libsecret libsoup wireplumber glib-networking ]);
      # needed for glib-networking to be found by the thing
      nativeBuildInputs = super.nativeBuildInputs ++ [ pkgs.wrapGAppsHook ];
    });
}
