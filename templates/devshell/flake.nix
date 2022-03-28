{
  inputs = {
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, devshell, flake-utils, nixpkgs }:
    flake-utils.lib.simpleFlake {
      inherit self nixpkgs;

      name = "devshell";
      preOverlays = [ devshell.overlay ];
      systems = flake-utils.lib.defaultSystems;

      shell = { pkgs }:
        pkgs.devshell.mkShell {
          motd = "";
          packages = with pkgs; [ ];
        };
    };
}
