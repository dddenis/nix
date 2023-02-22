{ inputs, outputs }:

let
  inherit (outputs) lib;

  x86_64-systems = map (nixosSystem "x86_64-linux") [
    ./ddd-pc/default.nix
  ];

  aarch64-systems = map (nixosSystem "aarch64-linux") [ ];

  overlay-unstable = _: prev: {
    unstable = inputs.nixpkgs.legacyPackages.${prev.system};
  };

  nixosSystem = system: configurationPath:
    let hostName = toString (lib.baseDirOf configurationPath);

    in
    lib.nameValuePair hostName (inputs.nixos.lib.nixosSystem {
      inherit system;

      specialArgs = { inherit lib inputs; };

      modules = [
        inputs.nixos.nixosModules.notDetected
        inputs.home-manager.nixosModules.home-manager
        inputs.neovim.nixosModules.neovim
        (toString configurationPath)
        ../modules

        {
          nix = {
            nixPath = [
              "nixpkgs=${inputs.nixpkgs}"
            ];

            registry = {
              config.flake = outputs;
              nixos.flake = inputs.nixos;
              nixpkgs.flake = inputs.nixpkgs;
            };
          };

          nixpkgs.overlays = [ overlay-unstable ];

          networking = { inherit hostName; };

          system = {
            configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
            stateVersion = outputs.stateVersion;
          };

          hm.home.stateVersion = outputs.stateVersion;
        }
      ];
    });

in
builtins.listToAttrs (x86_64-systems ++ aarch64-systems)
