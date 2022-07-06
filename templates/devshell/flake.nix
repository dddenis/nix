{
  inputs = {
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.inputs.flake-utils.follows = "flake-utils";

    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, devshell, flake-utils, nixpkgs }:
    let overlay = _: prev: { };

    in flake-utils.lib.simpleFlake {
      inherit self nixpkgs;

      name = "devshell";
      preOverlays = [ devshell.overlay overlay ];
      systems = flake-utils.lib.defaultSystems;

      shell = { pkgs }:
        pkgs.devshell.mkShell {
          motd = "";
          packages = with pkgs; [ ];
        };
    };
}
