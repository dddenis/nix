{ nixpkgs }:
_: prev:

{
  unstable = nixpkgs.legacyPackages.${prev.system};
}
