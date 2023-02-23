{
  inputs = {
    nixos.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-22.11";
    home-manager.inputs.nixpkgs.follows = "nixos";

    flake-utils.url = "github:numtide/flake-utils";

    kmonad.url = "github:kmonad/kmonad?dir=nix";
    kmonad.inputs.nixpkgs.follows = "nixos";

    neovim.url = "path:./flakes/neovim";
    neovim.inputs.nixpkgs.follows = "nixpkgs";
    neovim.inputs.flake-utils.follows = "flake-utils";
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

      nixosModules.default = import ./modules/nixos;

      homeModules.default = import ./modules/home-manager;

      templates = import ./templates { inherit (self) lib; };

      stateVersion = "22.11";
    });
}
