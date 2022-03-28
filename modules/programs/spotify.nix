{ config, lib, pkgs, ... }:

let cfg = config.programs.spotify;

in {
  options.programs.spotify.enable' = lib.mkEnableOption "spotify";

  config = lib.mkIf cfg.enable' {
    networking.firewall.allowedUDPPorts = [ 5353 ];

    hm.home.packages = [ pkgs.spotify ];
  };
}
