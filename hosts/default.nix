{ flake, lib, ... }:

let
  nixosSystem = system: configuration:
    let
      pkgs = if isDarwin then flake.nixpkgs else flake.nixos;
      home-manager = flake.home-manager."${if isDarwin then
        "darwinModules"
      else
        "nixosModules"}".home-manager;

      isDarwin = lib.hasInfix "darwin" system;

      commonModule = { lib, ... }: {
        nix = {
          nixPath = [
            "nixpkgs=${pkgs}"
            "nixos-config=${toString configuration}"
            "nixpkgs-overlays=${toString ../overlays-compat}"
            "/nix/var/nix/profiles/per-user/root/channels"
          ];

          registry.nixpkgs.flake = pkgs;
        };

        system.configurationRevision =
          lib.mkIf (flake.self ? rev) flake.self.rev;
      };

    in pkgs.lib.nixosSystem {
      inherit system;

      modules = [
        pkgs.nixosModules.notDetected
        home-manager
        commonModule
        configuration
      ];
    };

in { ddd-pc = nixosSystem "x86_64-linux" ./ddd-pc/configuration.nix; }
