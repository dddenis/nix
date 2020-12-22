{ lib ? (import <nixpkgs> { }).lib }:

let
  userConfigs = nixosConfig:
    lib.mapAttrsToList (username: userConfig:
      userConfig // {
        home = userConfig.home // { inherit username; };
      }) nixosConfig.home-manager.users;

in {
  anyConfig = f: nixosConfig: lib.any f (userConfigs nixosConfig);

  filterConfigs = f: nixosConfig: builtins.filter f (userConfigs nixosConfig);
}
