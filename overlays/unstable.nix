{ nixpkgs }:
_: prev:

{
  unstable = import nixpkgs {
    inherit (prev) system config;
  };
}
