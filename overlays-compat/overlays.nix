self: super:

let
  inherit (super) lib;
  inherit (import ../lib { inherit lib; }) fs;

  overlays = fs.importDirRec {
    path = toString ./..;
    regex = "overlay.nix";
  };

in lib.foldl' (lib.flip lib.extends) (_: super) overlays self
