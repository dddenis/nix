{ lib ? (import <nixpkgs> { }).lib }:

{
  concatAttrs = lib.foldr lib.recursiveUpdate { };
}
