{ config, lib, ... }:

let
  cfg = config.home;

  homeSymlinks = ''
    ${builtins.readFile ./updateSymlink.sh}
    ${lib.concatStrings (lib.mapAttrsToList updateSymlink cfg.symlink)}
  '';

  updateSymlink = dest: src: ''
    updateSymlink "${config.home.username}" "${src}" "${dest}"
  '';

in {
  options.home = {
    symlink = lib.mkOption {
      type = with lib.types; attrsOf string;
      default = { };
    };
  };

  config = {
    home.activation.homeSymlinks =
      lib.hm.dag.entryAfter [ "writeBoundary" ] homeSymlinks;
  };
}
