{ config, lib, pkgs, ... }:

let
  caches = {
    "https://hydra.iohk.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
  };

  normalUsers = builtins.attrNames (lib.filterAttrs
    (_: user: if user ? isNormalUser then user.isNormalUser else true)
    config.users.users);

in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  nix = {
    binaryCaches = builtins.attrNames caches;
    binaryCachePublicKeys = builtins.attrValues caches;
    trustedUsers = [ "root" ] ++ normalUsers;
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs = {
    overlays = [ (import ../overlays-compat/overlays.nix) ];
    config.allowUnfree = true;
  };
}
