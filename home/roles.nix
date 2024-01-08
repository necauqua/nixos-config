{ profiles, ... }: rec {
  all = builtins.attrValues profiles;
  headless = all ++ [{ headless = true; }];
}
