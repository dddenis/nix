{ inputs, outputs }:

let
  inherit (outputs) lib;

  nixosSystem = system: nixos: configurationPath:
    let hostName = toString (lib.baseDirOf configurationPath);

    in lib.nameValuePair hostName (nixos.lib.nixosSystem {
      inherit system;

      specialArgs = { inherit lib inputs; };

      modules = [
        nixos.nixosModules.notDetected
        inputs.home-manager.nixosModules.home-manager
        (toString configurationPath)
        ../modules

        {
          nix = {
            nixPath = [
              "nixos-config=${toString configurationPath}"
              "nixpkgs=${inputs.nixpkgs}"
            ];

            registry = {
              config.flake = outputs;
              nixos.flake = nixos;
              nixpkgs.flake = inputs.nixpkgs;
            };
          };

          networking = { inherit hostName; };

          system = {
            configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
            stateVersion = outputs.stateVersion;
          };

          hm.home.stateVersion = outputs.stateVersion;
        }
      ];
    });

in (builtins.listToAttrs
  (map (nixosSystem "aarch64-linux" inputs.nixos-aarch64) [
    ./ddd-kontist-utm/default.nix
    ./ddd-kontist-vmware/default.nix
  ])) // (builtins.listToAttrs
    (map (nixosSystem "x86_64-linux" inputs.nixos) [ ./ddd-pc/default.nix ]))
