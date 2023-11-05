{ inputs, outputs }:

let
  inherit (outputs) lib;

  configs = {
    aarch64-darwin = [
      ./ddd-complyance/default.nix
    ];
    x86_64-linux = [
      ./ddd-pc/default.nix
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
    let hostName = toString (lib.baseDirOf config);

    in
    lib.nameValuePair hostName (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixos {
        inherit system;
        overlays = [ outputs.overlays.default ];
        config.allowUnfree = true;
      };

      extraSpecialArgs = { inherit inputs outputs; };

      modules = [
        outputs.homeModules.default
        config
      ];
    });

in
homeConfigs configs
