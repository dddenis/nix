{
  inputs = {
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    let overlay = _: prev: { };

    in
    flake-utils.lib.simpleFlake {
      inherit self nixpkgs;

      name = "devshell";
      systems = flake-utils.lib.defaultSystems;

      preOverlays = [
        inputs.devshell.overlays.default
        overlay
      ];

      shell = { pkgs }:
        pkgs.devshell.mkShell {
          motd = "";
          packages = with pkgs; [ ];
        };
    };
}
