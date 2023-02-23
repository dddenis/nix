{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.services.xserver.desktopManager.gnome;

in
{
  options.ddd.services.xserver.desktopManager.gnome.enable =
    lib.mkEnableOption "gnome";

  config = lib.mkIf cfg.enable {
    programs.dconf.enable = true;

    services = {
      udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

      xserver = {
        enable = true;

        desktopManager.gnome = {
          enable = true;
          sessionPath = with pkgs.gnome; [ mutter ];
        };

        displayManager.gdm.enable = true;
      };
    };
  };
}
