{ lib ? (import <nixpkgs> { }).lib }:

let
  callLibs = file: import file { lib = lib // extension; };

  extension = rec {
    attrsets = lib.attrsets // callLibs ./attrsets.nix;
    inherit (attrsets) recursiveUpdateAll;

    filesystem = lib.filesystem // callLibs ./filesystem.nix;
    inherit (filesystem) baseDirOf fileName findFilesRec readDirRec;
  };

in extension
