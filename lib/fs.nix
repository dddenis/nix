{ lib ? (import <nixpkgs> { }).lib }:

let
  inherit (lib) attrsets lists;
  inherit (builtins) filter isAttrs mapAttrs match readDir;

  joinPath = a: b: a + "/${b}";

in rec {
  readDirRec = path:
    let
      processEntry = name: type:
        let entryPath = joinPath path name;

        in if type == "directory" then readDirRec entryPath else entryPath;

    in mapAttrs processEntry (readDir path);

  findFilesRec = { path, regex ? "default.nix" }:
    let
      f = name: value:
        if isAttrs value then
          findFilesRec {
            path = joinPath path name;
            inherit regex;
          }
        else if match regex name == null then
          [ ]
        else
          [ (joinPath path name) ];

    in lists.flatten (attrsets.mapAttrsToList f (readDirRec path));

  importDirRec = { path, regex ? "default.nix" }:
    let
      f = filePath: if dirOf filePath == path then null else import filePath;
      imports = map f (findFilesRec { inherit path regex; });

    in lists.remove null imports;
}
