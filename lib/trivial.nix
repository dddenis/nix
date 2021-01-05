{ lib ? (import <nixpkgs> { }).lib }:

{
  flow = lib.flip lib.pipe;

  not = f: x: !(f x);

  withDefault = def: x: if x == null then def else x;
}
