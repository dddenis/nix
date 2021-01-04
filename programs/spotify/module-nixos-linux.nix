{ config, pkgs, lib, ... }:

let
  isEnabled =
    pkgs.lib.user.anyConfig (userConfig: userConfig.programs.spotify.enable')
    config;

in lib.mkIf isEnabled { networking.firewall.allowedUDPPorts = [ 5353 ]; }

