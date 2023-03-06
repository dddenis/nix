{ inputs, outputs }:

let
  inherit (outputs) lib;

  systemConfigs = {
    x86_64-linux = [
      ./ddd-complyance/default.nix
      ./ddd-pc/default.nix
    ];
  };

  nixosSystems = systemConfigs:
    let
      allSystems =
        lib.mapAttrsToList
          (system: hostConfigs: map (nixosSystem system) hostConfigs)
          systemConfigs;
    in
    builtins.listToAttrs (lib.flatten allSystems);

  nixosSystem = system: hostConfig:
    let hostName = toString (lib.baseDirOf hostConfig);

    in
    lib.nameValuePair hostName (inputs.nixos.lib.nixosSystem {
      inherit system;

      specialArgs = { inherit lib inputs outputs; };

      modules = [
        outputs.nixosModules.default
        hostConfig
        { networking.hostName = hostName; }
      ];
    });

in
nixosSystems systemConfigs
