{ lib, ... }:

let inherit (import ../lib { inherit lib; }) fs;

in { imports = fs.importDirRec { path = toString ./.; }; }
