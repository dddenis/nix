{ pkgs, ... }:

{
  home.username = "ddd";

  home.packages = with pkgs; [
    unstable.discord
    unstable.firefox-wayland
    unstable.spotify
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
