{ pkgs, ... }:

{
  profiles.gui.enable = true;

  home.username = "ddd";

  home.packages = with pkgs; [
    docker
    insomnia

    unstable.discord
    unstable.firefox-wayland
    unstable.spotify
    unstable.tdesktop
  ];

  ddd.hosts = {
    abra.enable = true;
  };

  ddd.services = {
    safeeyes.enable = true;
    xserver.desktopManager.gnome.enable = true;
  };

  sops.defaultSopsFile = ./secrets.yaml;
}
