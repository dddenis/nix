{ lib ? (import <nixpkgs> { }).lib }:

let joinPath = a: b: a + "/${b}";

in rec {
  baseDirOf = path:
    let dir = toString (dirOf path);
    in lib.last (lib.splitString "/" dir);

  fileName = path:
    if lib.pathIsDirectory path then
      null
    else
      lib.pipe path [
        builtins.baseNameOf
        (lib.splitString ".")
        lib.init
        (lib.concatStringsSep ".")
      ];

  findFilesRec = { path, regex ? "default.nix" }:
    let
      f = name: value:
        if builtins.isAttrs value then
          findFilesRec {
            path = joinPath path name;
            inherit regex;
          }
        else if builtins.match regex name == null then
          [ ]
        else
          [ (joinPath path name) ];

    in lib.flatten (lib.mapAttrsToList f (readDirRec path));

  importDirRec = { path, regex ? "default.nix" }:
    let
      f = filePath: if dirOf filePath == path then null else import filePath;
      imports = map f (findFilesRec { inherit path regex; });

    in lib.remove null imports;

  readDirRec = path:
    let
      processEntry = name: type:
        let entryPath = joinPath path name;

        in if type == "directory" then readDirRec entryPath else entryPath;

    in builtins.mapAttrs processEntry (builtins.readDir path);
}
