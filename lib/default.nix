{ lib ? (import <nixpkgs> { }).lib }:

let
  callLibs = file: import file { lib = lib // extension; };

  extension = rec {
    filesystem = lib.filesystem // callLibs ./filesystem.nix;
    inherit (filesystem) baseDirOf fileName findFilesRec readDirRec;
  };

in extension
