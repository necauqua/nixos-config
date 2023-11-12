{ pkgs, ... }: {

  home.packages = with pkgs; [
    nix-tree
    cachix

    iw
    ffmpeg

    man-db
    tldr
    expect
    rlwrap
    jq
    ijq
    jless
    fzf
    nmap
    calc
    traceroute
    dig
    zip
    unzip
    tree
    usbutils
    yt-dlp

    gh
    asciinema
    ripgrep
    ncspot
    screenfetch

    exfatprogs
    ntfs3g
    smartmontools

    gifski

    lua5_3.pkgs.luacheck
    lua5_3.pkgs.tl

    nixpkgs-fmt

    packwiz

    awscli2
    ranger
  ];
}
