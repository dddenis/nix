{ lib ? (import <nixpkgs> { }).lib }:

{
  flow = lib.flip lib.pipe;

  withDefault = def: x: if x == null then def else x;
}
