{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos.url = "nixpkgs/nixos-unstable";
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs@{ self, flake-utils, nixpkgs, ... }:
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

      importModules = regex: _: {
        imports = self.lib.fs.importDirRec {
          inherit regex;
          path = toString ./.;
        };
      };

    in defaultSystems // {
      lib = import ./lib { inherit (nixpkgs) lib; };

      nixosConfigurations = import ./hosts {
        lib = import ./lib/extended-lib.nix nixpkgs.lib;
        inputs = removeAttrs inputs [ "self" ];
        outputs = self;
      };

      nixosModule = importModules "module-nixos.nix";

      homeModule = importModules "module-home.nix";

      overlay = import ./overlays-compat/overlays.nix;

      stateVersion = "20.09";
    };
}
