self: super:

let
  inherit (super) lib;
  fs = import ../lib/fs.nix { inherit lib; };

  overlays = fs.importDirRec {
    path = toString ./..;
    regex = "overlay.nix";
  };

in lib.foldl' (lib.flip lib.extends) (_: super) overlays self
