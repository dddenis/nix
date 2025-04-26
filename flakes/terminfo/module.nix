{ config, lib, pkgs, ... }:

# Darwin ships with old ncurses version
# This module patches and installs terminfo from new ncurses version

let
  cfg = config.ddd.misc.terminfo;

  terminfo = pkgs.runCommandLocal "terminfo"
    {
      TERMINFO_NAMES = cfg.names;
    }
    ''
      mkdir -p $out/share/terminfo

      for terminfo in $TERMINFO_NAMES; do
        ${pkgs.ncurses}/bin/infocmp -x "$terminfo" | \
          sed -e 's/pairs#0x10000/pairs#0x1000/' -e 's/pairs#65536/pairs#32768/' \
          > "$terminfo.src"
        ${pkgs.ncurses}/bin/tic -x -o $out/share/terminfo "$terminfo.src"
      done
    '';

  terminfoDirs = "${config.home.homeDirectory}/.nix-profile/share/terminfo";

in
{
  options.ddd.misc.terminfo.names = lib.mkOption {
    type = lib.types.listOf lib.types.nonEmptyStr;
    default = [ ];
  };

  config = lib.mkIf (pkgs.stdenv.isDarwin && cfg.names != [ ]) {
    home.packages = [ terminfo ];
    home.sessionVariables = {
      TERMINFO_DIRS = terminfoDirs;
    };
    home.file.".terminfo".source = config.lib.file.mkOutOfStoreSymlink terminfoDirs;
  };
}
