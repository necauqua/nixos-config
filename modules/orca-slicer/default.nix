{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.orca-slicer.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        # filament sync of the Snapmaker U1 picks the vendor preset of the
        # reported sub-type (e.g. "SUNLU PLA Matte"), not the generic one
        ./snapmaker-filament-sync.patch
        # the filename_format template can use initial_no_support_extruder
        (pkgs.fetchpatch {
          url = "https://github.com/OrcaSlicer/OrcaSlicer/commit/0a55e6ef83b21a8057597f3374fee05c665d8f23.patch";
          hash = "sha256-6jYOvmnPliBPA9usOImAQdlSNhfaIOjSiHYvrHJwNWQ=";
        })
        # the U1 file name has the type of the filament that the print
        # uses, not of the filament in the first slot
        (pkgs.fetchpatch {
          url = "https://github.com/OrcaSlicer/OrcaSlicer/commit/f31e610b726a3050c83dc700066661d2c296cb1c.patch";
          hash = "sha256-agICdfEHcclLlv0MaJfPChpgsDRQcwCig7BaK2iWKlc=";
        })
      ];
      # Orca copies the bundled profiles of a vendor to the user data only
      # when their version is newer than that of the copy
      postPatch = (old.postPatch or "") + ''
        substituteInPlace resources/profiles/Snapmaker.json \
          --replace-fail '"version": "02.04.00.07"' '"version": "02.04.00.08"'
      '';
    }))
  ];
}
