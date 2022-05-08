{ inputs, outputs }:

let
  inherit (outputs) lib;

  nixosSystem = system: configurationPath:
    let hostName = toString (lib.baseDirOf configurationPath);

    in lib.nameValuePair hostName (inputs.nixos.lib.nixosSystem {
      inherit system;

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

in (builtins.listToAttrs (map (nixosSystem "aarch64-linux") [
  ./ddd-kontist-utm/default.nix
  ./ddd-kontist-vmware/default.nix
])) // (builtins.listToAttrs
  (map (nixosSystem "x86_64-linux") [ ./ddd-pc/default.nix ]))
