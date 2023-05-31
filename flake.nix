{
  inputs = {
    nixos.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixos";

    kmonad.url = "github:kmonad/kmonad?dir=nix";
    kmonad.inputs.nixpkgs.follows = "nixos";
  };

  outputs = inputs@{ self, nixos, nixpkgs, flake-utils, ... }:
    (rec {
      lib = import ./lib/extended-lib.nix nixos.lib;

      overlays = import ./overlays {
        inherit lib nixpkgs;
      };

      nixosConfigurations = import ./hosts {
        inputs = removeAttrs inputs [ "self" ];
        outputs = self;
      };

      homeConfigurations = import ./home {
        inputs = removeAttrs inputs [ "self" ];
        outputs = self;
      };

      nixosModules.default = import ./modules/nixos;

      homeModules.default = import ./modules/home-manager;

      templates = import ./templates { inherit (self) lib; };

      stateVersion = "23.05";
    });
}
