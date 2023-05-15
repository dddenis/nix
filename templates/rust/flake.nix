{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.inputs.flake-utils.follows = "flake-utils";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlay = _: prev: { };

        pkgs = import nixpkgs {
          inherit system;

          overlays = [
            inputs.devshell.overlays.default
            inputs.fenix.overlays.default
            overlay
          ];
        };

        toolchain = pkgs.fenix.complete.withComponents [
          "cargo"
          "clippy"
          "rust-src"
          "rustc"
          "rustfmt"
        ];

      in
      {
        devShell = pkgs.devshell.mkShell {
          motd = "";

          packages = with pkgs; [
            stdenv.cc
            toolchain
            fenix.rust-analyzer
          ];
        };
      }
    );
}
