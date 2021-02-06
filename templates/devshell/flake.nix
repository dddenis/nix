{
  inputs = {
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, devshell, flake-utils, nixpkgs }:
    flake-utils.lib.simpleFlake {
      inherit self nixpkgs;

      name = "devshell";
      preOverlays = [ devshell.overlay ];
      systems = flake-utils.lib.defaultSystems;

      config.allowUnfree = true;

      shell = { pkgs }:
        pkgs.devshell.mkShell {
          motd = "";
          packages = with pkgs; [ ];
        };
    };
}
