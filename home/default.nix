{ inputs, outputs }:

let
  inherit (outputs) lib;

  configs = {
    aarch64-darwin = [
      ./ddd-complyance.nix
    ];
  };

  homeConfigs = configs:
    let
      allConfigs =
        lib.mapAttrsToList
          (system: config: map (homeConfig system) config)
          configs;
    in
    builtins.listToAttrs (lib.flatten allConfigs);

  homeConfig = system: config:
    lib.nameValuePair (lib.fileName config) (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixos {
        inherit system;
        overlays = [ outputs.overlays.default ];
        config.allowUnfree = true;
      };

      extraSpecialArgs = { inherit inputs outputs; };

      modules = [
        outputs.homeModules.default
        config
        { programs.home-manager.enable = true; }
      ];
    });

in
homeConfigs configs
