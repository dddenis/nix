let
  caches = {
    "https://hydra.iohk.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
  };

in {
  nix = {
    binaryCaches = builtins.attrNames caches;
    binaryCachePublicKeys = builtins.attrValues caches;
    trustedUsers = [ "root" ];
  };
}
