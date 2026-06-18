{ nixpkgs }:
_: prev:

{
  unstable = import nixpkgs {
    inherit (prev) config;
    system = prev.stdenv.hostPlatform.system;
  };
}
