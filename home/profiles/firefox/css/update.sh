#!/usr/bin/env nix
#! nix shell nixpkgs#curl --command bash

# bruh one can add the repo to flake inputs or bother with git submodules
# or we can just copy over the few files we need like this lul
#
# the only downside is having to manually run this *sometimes*

csshacks=(
  "autohide_toolbox"
  "autohide_sidebar"
  "hide_tabs_toolbar_v2"
)

for hack in "${csshacks[@]}"; do
  curl -LO "https://raw.githubusercontent.com/MrOtherGuy/firefox-csshacks/refs/heads/master/chrome/$hack.css"
done

