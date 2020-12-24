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

  outputs = input@{ self, flake-utils, home-manager, nixos, nixpkgs }:
    let
      extendedLib = import ./lib/extended-lib.nix nixpkgs.lib;

      normalizedInput = {
        flake = input;
        lib = extendedLib;
      };

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

    in defaultSystems // {
      lib = import ./lib { inherit (nixpkgs) lib; };

      nixosConfigurations = import ./hosts normalizedInput;

      overlay = import ./overlays-compat/overlays.nix;
    };
}
