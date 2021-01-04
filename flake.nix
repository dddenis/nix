{
  inputs = {
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos.url = "nixpkgs/nixos-unstable";
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs@{ self, darwin, flake-utils, nixpkgs, ... }:
    let
      defaultSystems = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlay ];
          };

        in {
          apps.repl = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "repl" ''
              repl=$(mktemp)
              echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" > $repl
              trap "rm -rf $repl" EXIT
              nix repl $repl
            '';
          };
        });

      hosts = import ./hosts {
        inherit (self) lib;
        inputs = removeAttrs inputs [ "self" ];
        outputs = self;
      };

      mkModules = systemType: {
        system = mkModule "nixos" systemType;
        home = mkModule "home" systemType;
      };

      mkModule = moduleType: systemType: {
        imports = (self.lib.importDirRec {
          regex = "module-${moduleType}(-${systemType})?.nix";
          path = toString ./.;
        });
      };

    in defaultSystems // hosts // {
      lib = import ./lib/extended-lib.nix nixpkgs.lib;

      nixosModules = mkModules "linux";

      darwinModules = mkModules "darwin";

      overlay = import ./overlays-compat/overlays.nix;

      stateVersion = "20.09";

      templates = import ./templates { inherit (nixpkgs) lib; };
    };
}
