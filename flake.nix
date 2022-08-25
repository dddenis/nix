{
  inputs = {
    nixos.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixos-aarch64.url = "github:NixOS/nixpkgs/nixos-22.05-aarch64";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-22.05";
    home-manager.inputs.nixpkgs.follows = "nixos";

    coc-nvim.url = "github:neoclide/coc.nvim/v0.0.81";
    coc-nvim.flake = false;
  };

  outputs = inputs@{ self, nixos, ... }: {
    lib = import ./lib/extended-lib.nix nixos.lib;

    nixosConfigurations = import ./hosts {
      inputs = removeAttrs inputs [ "self" ];
      outputs = self;
    };

    stateVersion = "22.05";

    templates = import ./templates { inherit (self) lib; };
  };
}
