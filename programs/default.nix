{ lib, ... }:

{
  imports = (import ../lib/fs.nix { inherit lib; }).importDirRec {
    path = toString ./.;
  };
}
