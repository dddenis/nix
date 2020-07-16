{ lib ? (import <nixpkgs> { }).lib }:

{
  fs = import ./fs.nix { inherit lib; };
}
