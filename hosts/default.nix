{ inputs, outputs }:

let
  inherit (outputs) lib;

  nixosSystem = configurationPath:
    let hostName = toString (lib.baseDirOf configurationPath);

    in lib.nameValuePair hostName (inputs.nixos.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = { inherit lib inputs; };

      modules = [
        inputs.nixos.nixosModules.notDetected
        inputs.home-manager.nixosModules.home-manager
        (toString configurationPath)
        ../modules

        {
          nix = {
            nixPath = [
              "nixos-config=${toString configurationPath}"
              "nixpkgs=${inputs.nixos}"
            ];

            registry = {
              config.flake = outputs;
              nixpkgs.flake = inputs.nixos;
            };
          };

          networking = { inherit hostName; };

          system = {
            configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
            stateVersion = outputs.stateVersion;
          };
        }
      ];
    });

in builtins.listToAttrs (map nixosSystem (lib.findFilesRec {
  path = ./.;
  regex = "default.nix";
  excludeDirs = [ ./. ];
}))
