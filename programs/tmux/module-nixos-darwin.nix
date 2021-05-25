{ config, lib, pkgs, ... }:

let
  isEnabled =
    lib.user.anyConfig (userConfig: userConfig.programs.tmux.enable') config;

  terminfo = pkgs.stdenv.mkDerivation {
    pname = "terminfo";
    inherit (pkgs.ncurses) src version;

    phases = [ "unpackPhase" "installPhase" ];

    installPhase = ''
      cp misc/terminfo.src $out
    '';
  };

in lib.mkIf isEnabled {
  environment.extraInit = ''
    tic -xe tmux,tmux-256color ${terminfo}
  '';
}
