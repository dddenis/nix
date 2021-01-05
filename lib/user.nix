{ lib ? (import <nixpkgs> { }).lib }:

rec {
  configs = nixosConfig:
    lib.mapAttrsToList (username: userConfig:
      userConfig // {
        home = userConfig.home // { inherit username; };
      }) nixosConfig.home-manager.users;

  anyConfig = f: nixosConfig: lib.any f (configs nixosConfig);

  filterConfigs = f: nixosConfig: builtins.filter f (configs nixosConfig);

  filterMapConfigs = f: nixosConfig:
    lib.pipe nixosConfig [ configs (map f) (builtins.filter (lib.not isNull)) ];
}
