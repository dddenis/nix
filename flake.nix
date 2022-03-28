{
  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixos";
    };
    nixos.url = "nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ self, nixos, ... }: {
    lib = import ./lib/extended-lib.nix nixos.lib;

    nixosConfigurations = import ./hosts {
      inputs = removeAttrs inputs [ "self" ];
      outputs = self;
    };

    stateVersion = "21.11";

    templates = import ./templates { inherit (self) lib; };
  };
}
