{ lib ? (import <nixpkgs> { }).lib }:

let
  mkCustomLib = lib: {
    inherit (import ./attrsets.nix { inherit lib; }) concatAttrs;

    fs = import ./fs.nix { inherit lib; };

    withDefault = def: x: if x == null then def else x;
  };

in lib.extend (_: mkCustomLib)
