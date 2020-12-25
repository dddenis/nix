{ config, pkgs, lib, ... }:

let
  isEnabled = pkgs.lib.user.anyConfig
    (userConfig: userConfig.programs.spotify.enable') config;

in {
  config = lib.mkIf isEnabled { networking.firewall.allowedUDPPorts = [ 5353 ]; };
}
