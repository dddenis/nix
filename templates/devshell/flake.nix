{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
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
      devShells = perSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ ];
        };
      });
    };
}
