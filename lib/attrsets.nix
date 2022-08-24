{ lib ? (import <nixpkgs> { }).lib }:

rec {
  recursiveUpdateAll = lib.lists.foldl lib.attrsets.recursiveUpdate { };
}
