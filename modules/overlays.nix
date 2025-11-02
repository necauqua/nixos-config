{ pkgs, ... }:
let
  # todo replace this with pkgs.symlinkJoin { ..; postBuild = "wrap" }
  wrap = pkg: flags:
    let
      name = pkg.meta.mainProgram or pkg.pname;
    in
    pkgs.runCommand pkg { buildInputs = [ pkgs.makeWrapper ]; } ''
      mkdir $out
      # Link every top-level folder from pkg to our new target
      ln -s ${pkg}/* $out
      # Except the bin folder
      rm $out/bin
      # We create the bin folder ourselves and link every binary in it
      mkdir $out/bin
      ln -s ${pkg}/bin/* $out/bin
      # Except the binary
      rm $out/bin/${name}
      # Because we create it ourself, by creating a wrapper
      makeWrapper ${pkg}/bin/${name} $out/bin/${name} --inherit-argv0 ${flags}

      # Repeat the same thing to have real share/applications copied
      rm $out/share
      mkdir $out/share
      ln -s ${pkg}/share/* $out/share

      rm $out/share/applications
      mkdir $out/share/applications
      # for some weird reason cp -r applications did not work (the copied folder had some temp file which threw off sed _somehow_)
      cp ${pkg}/share/applications/*.desktop $out/share/applications

      # And substitute paths in the desktop files
      sed -i s%${pkg}%$out%g $out/share/applications/*.desktop
    '';
in
{
  nixpkgs.overlays = [
    (final: prev: {
      xserver-bug865 = prev.xorg.xorgserver.overrideAttrs (super: {
        pname = "xorgserver-bug865";
        patches = super.patches ++ [
          (prev.fetchpatch {
            name = "freedesktop-bug-865.patch";
            url = "https://aur.archlinux.org/cgit/aur.git/plain/freedesktop-bug-865.patch?h=xorg-server-bug865";
            sha256 = "sha256-ZZFjzc9QzrNL3pJLYYeanEEa1KoQstmkz42ryfOdmb4=";
          })
        ];
      });
      telegram-desktop = (wrap prev.telegram-desktop "--set LC_TIME C --set XDG_CURRENT_DESKTOP gnome");

      helix = (wrap prev.helix "--suffix PATH : ${with pkgs; lib.makeBinPath [
        nil
        rust-analyzer
        zls
        typescript-language-server        
        vscode-langservers-extracted
      ]}");
    })
  ];
}
