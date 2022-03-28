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

  findFilesRec = { path, regex ? ".*", excludeDirs ? [ ] }:
    let
      processEntry = name: value:
        let
          joinedPath = joinPath path name;
          isInExcludeDirs = builtins.elem path excludeDirs;
          matchesRegex = builtins.match regex name != null;

        in if builtins.isAttrs value then
          findFilesRec {
            path = joinedPath;
            inherit regex excludeDirs;
          }
        else if isInExcludeDirs || !matchesRegex then
          [ ]
        else
          [ joinedPath ];

    in lib.flatten (lib.mapAttrsToList processEntry (readDirRec path));

  readDirRec = path:
    let
      processEntry = name: type:
        let entryPath = joinPath path name;
        in if type == "directory" then readDirRec entryPath else entryPath;

    in builtins.mapAttrs processEntry (builtins.readDir path);
}
