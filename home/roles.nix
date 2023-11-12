{ load-modules, ... }:
let
  profiles = load-modules ./profiles;
in
{
  all = builtins.attrValues profiles;
}
