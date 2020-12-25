{ lib ? (import <nixpkgs> { }).lib }:

{
  # [attrset] -> attrset
  concatAttrs = lib.foldr lib.recursiveUpdate { };
}
