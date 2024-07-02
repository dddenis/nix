{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, fenix, ... }:
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
            overlays = [
              fenix.overlays.default
              overlay
            ];
          };

        in
        f pkgs
      );

    in
    {
      devShells = perSystem (pkgs:
        let
          rust-toolchain = pkgs.fenix.complete.withComponents [
            "cargo"
            "clippy"
            "rust-src"
            "rustc"
            "rustfmt"
          ];

        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              libiconv
              rust-toolchain
              rust-analyzer-nightly
            ];
          };
        });
    };
}

