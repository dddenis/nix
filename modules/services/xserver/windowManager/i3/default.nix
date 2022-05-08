{ config, lib, pkgs, ... }:

let cfg = config.services.xserver.windowManager.i3;

in {
  options.services.xserver.windowManager.i3.enable' = lib.mkEnableOption "i3";

  config = lib.mkIf cfg.enable' {
    services.xserver.windowManager.i3.enable = true;
    services.xserver.windowManager.i3.configFile = ./i3-config;
  };
}

