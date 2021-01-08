args@{ lib, inputs, outputs }:

let
  nixosSystem = hostName:
    inputs.nixos.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        inputs.nixos.nixosModules.notDetected
        outputs.nixosModules.system
        inputs.home-manager.nixosModules.home-manager
        (homeManagerModule outputs.nixosModules.home)
        (commonModule {
          inherit hostName;
          pkgs = inputs.nixos;
        })

        {
          nix = {
            nixPath =
              [ "nixos-config=${toString (getConfiguration hostName)}" ];

            registry = {
              config.flake = outputs;
              nixpkgs.flake = inputs.nixos;
            };
          };

          system = {
            configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
            stateVersion = outputs.stateVersion;
          };

          users.users = mapUserConfigs hostName (_: _: {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
          });
        }
      ];
    };

  darwinSystem = hostName:
    inputs.darwin.lib.darwinSystem {
      specialArgs = { inherit lib; };

      modules = [
        outputs.darwinModules.system
        inputs.home-manager.darwinModules.home-manager
        (homeManagerModule outputs.darwinModules.home)
        (commonModule {
          inherit hostName;
          pkgs = inputs.nixpkgs;
        })

        { environment.darwinConfig = toString (getConfiguration hostName); }
      ];
    };

  homeManagerModule = module: {
    options.home-manager.users = lib.mkOption {
      type = with lib.types; attrsOf (submoduleWith { modules = [ module ]; });
    };
  };

  commonModule = { hostName, pkgs }: {
    imports = [ (getConfiguration hostName) ];

    home-manager.users = mapUserConfigs hostName (_: path: {
      imports = [ path ];

      home.stateVersion = outputs.stateVersion;

      systemd.user.startServices = "sd-switch";
    });

    networking = { inherit hostName; };

    nix.nixPath =
      [ "nixpkgs=${pkgs}" "nixpkgs-overlays=${toString ../overlays-compat}" ];
  };

  getConfiguration = hostName: ./. + "/${hostName}/configuration.nix";

  mapUserConfigs = hostName: f:
    lib.pipe (./. + "/${hostName}/users") [
      lib.filesystem.listFilesRecursive
      (map (userConfig: lib.nameValuePair (lib.fileName userConfig) userConfig))
      builtins.listToAttrs
      (builtins.mapAttrs f)
    ];

in {
  nixosConfigurations = lib.genAttrs [ "ddd-pc" ] nixosSystem;

  darwinConfigurations = lib.genAttrs [ "ddd-mcmakler" ] darwinSystem;
}
