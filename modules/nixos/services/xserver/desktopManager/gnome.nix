{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.services.xserver.desktopManager.gnome;

in
{
  options.ddd.services.xserver.desktopManager.gnome.enable =
    lib.mkEnableOption "gnome";

  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      XCURSOR_THEME = "Adwaita";
    };

    programs.dconf.enable = true;

    services = {
      gnome.gcr-ssh-agent.enable = false;

      udev.packages = with pkgs; [ gnome-settings-daemon ];

      desktopManager.gnome = {
        enable = true;
        sessionPath = with pkgs; [ mutter ];
      };

      displayManager.gdm.enable = true;

      xserver.enable = true;
    };
  };
}
