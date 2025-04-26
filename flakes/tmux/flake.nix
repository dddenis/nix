{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    terminfo.url = "../terminfo";
    terminfo.inputs.nixpkgs.follows = "nixpkgs";
    terminfo.inputs.home-manager.follows = "home-manager";
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    homeManagerModule = import ./module.nix;
  };
}
