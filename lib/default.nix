{ lib ? (import <nixpkgs> { }).lib }:

let callLibs = file: import file { inherit lib; };

in rec {
  attrsets = lib.attrsets // callLibs ./attrsets.nix;
  inherit (attrsets) concatAttrs;

  filesystem = lib.filesystem // callLibs ./filesystem.nix;
  inherit (filesystem) baseDirOf fileName findFilesRec importDirRec readDirRec;

  lists = lib.lists // callLibs ./lists.nix;
  inherit (lists) isEmpty;

  trivial = lib.trivial // callLibs ./trivial.nix;
  inherit (trivial) flow withDefault;

  user = callLibs ./user.nix;
}
