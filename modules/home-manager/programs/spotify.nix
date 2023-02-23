{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.spotify;

in
{
  options.ddd.programs.spotify.enable = lib.mkEnableOption "spotify";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.spotify ];
  };
}
