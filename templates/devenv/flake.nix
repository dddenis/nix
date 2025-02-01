{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = inputs@{ self, nixpkgs, devenv, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      overlay = _: prev: { };

      perSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };

        in
        f pkgs
      );

    in
    {
      packages = perSystem (pkgs: {
        devenv-up = self.devShells.${pkgs.system}.default.config.procfileScript;
        devenv-test = self.devShells.${pkgs.system}.default.config.test;
      });

      devShells = perSystem (pkgs:
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;

            modules = [
              {
                packages = with pkgs; [ ];
              }
            ];
          };
        });
    };
}
