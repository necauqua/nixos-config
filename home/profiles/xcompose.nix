{ lib, ... }:
let
  items = {
    Cyrillic_yeru = "і";
    Cyrillic_YERU = "І";
    Cyrillic_hardsign = "ї";
    Cyrillic_HARDSIGN = "Ї";

    Cyrillic_e = "є";
    Cyrillic_E = "Є";

    Cyrillic_ghe = "ґ";
    Cyrillic_GHE = "Ґ";

    Cyrillic_io = "’";

    c = "ç";
    C = "Ç";

    asciicircum = "⌄";
    o = "°";

    s = "¯\\_(ツ)_/¯";
    S = "🤷";

    l = "λ";
    a = "α";
    b = "β";
    d = "δ";
    D = "Δ";

    "2" = "²";
    "3" = "³";
    x = "×";
    A = "∀";

    o-e = "œ";
    O-E = "Œ";
    a-e = "æ";
    A-E = "Æ";

    h-h = "←";
    j-j = "↓";
    k-k = "↑";
    l-l = "→";

    j-k = "↕";
    k-j = "↕";
    h-l = "↔";
    l-h = "↔";

    c-o = "©";
    p-h = "💜";
  };

  f = k: v:
    let
      keys = lib.splitString "-" k;
      mapped = builtins.map (k: "<${k}>") keys;
      joined = lib.concatStringsSep " " mapped;
    in
    "<Multi_key> ${joined} : \"${v}\"";

  text = builtins.concatStringsSep "\n" (lib.mapAttrsToList f items);
in
{
  home.file.".XCompose".text = text;
}
