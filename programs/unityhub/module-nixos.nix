{ config, pkgs, lib, ... }:

let
  isEnabled = pkgs.lib.user.anyConfig
    (userConfig: userConfig.programs.unityhub.enable') config;

in {
  config = lib.mkIf isEnabled {
    networking.firewall.allowedUDPPorts = [ 34997 54997 ];
  };
}