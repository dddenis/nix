self: super:

let
  inherit (super) lib;
  filesystem = import ../lib/filesystem.nix { inherit lib; };

  overlays = filesystem.importDirRec {
    path = toString ./..;
    regex = "overlay.nix";
  };

in lib.foldl' (lib.flip lib.extends) (_: super) overlays self
