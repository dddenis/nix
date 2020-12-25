args@{ lib, inputs, outputs }:

let
  nixosSystem = { hostName, system, users }:
    let
      config = ./. + "/${hostName}/configuration.nix";

      pkgs = if isDarwin then inputs.nixpkgs else inputs.nixos;

      home-manager = inputs.home-manager."${if isDarwin then
        "darwinModules"
      else
        "nixosModules"}".home-manager;

      isDarwin = lib.hasInfix "darwin" system;

      commonModule = { lib, ... }: {
        home-manager.users = lib.getAttrs users (import ../users args);

        networking = { inherit hostName; };

        nix = {
          nixPath = [
            "nixpkgs=${pkgs}"
            "nixos-config=${toString config}"
            "nixpkgs-overlays=${toString ../overlays-compat}"
            "/nix/var/nix/profiles/per-user/root/channels"
          ];

          registry.nixpkgs.flake = pkgs;
        };

        system = {
          configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
          stateVersion = outputs.stateVersion;
        };

        users.users = lib.genAttrs users (_: {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
        });
      };

    in {
      "${hostName}" = pkgs.lib.nixosSystem {
        inherit system;

        modules = [
          pkgs.nixosModules.notDetected
          outputs.nixosModule
          home-manager
          commonModule
          config
        ];
      };
    };

in nixosSystem {
  hostName = "ddd-pc";
  system = "x86_64-linux";
  users = [ "ddd" ];
}
