{ pkgs, ... }:

{
  home.username = "ddd";

  home.packages = with pkgs; [
    firefox-wayland
    spotify

    unstable.discord
    unstable.tdesktop
  ];

  ddd.hosts = {
    abra.enable = true;
  };

  ddd.services = {
    xserver.desktopManager.gnome.enable = true;
  };

  sops.defaultSopsFile = ./secrets.yaml;
}
