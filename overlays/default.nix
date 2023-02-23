{ lib, nixpkgs }:

let
  overlays = {
    iosevka = import ./iosevka.nix;
    unstable = import ./unstable.nix { inherit nixpkgs; };
  };

in
overlays // {
  default = final: prev:
    lib.composeManyExtensions
      (builtins.attrValues overlays)
      final
      prev;
}
