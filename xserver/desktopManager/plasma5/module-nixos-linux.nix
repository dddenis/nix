{ config, lib, pkgs, ... }:

let cfg = config.services.xserver.desktopManager.plasma5;

in {
  options.services.xserver.desktopManager.plasma5 = {
    enable' = lib.mkEnableOption "KDE Plasma 5";
  };

  config = lib.mkIf cfg.enable' {
    services.xserver = {
      enable = true;

      displayManager = {
        sddm.enable = true;

        session = [{
          name = "xsession";
          start = "${pkgs.runtimeShell} $HOME/.xsession-hm & waitPID=$!";
          manage = "window";
        }];
      };

      desktopManager.plasma5.enable = true;
    };
  };
}
