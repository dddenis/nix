{ pkgs, ... }:

{
  home.username = "ddd";

  home.packages = with pkgs; [
    chromium
    firefox-wayland
    inkscape
    krita
    slack

    unstable.discord
    unstable.spotify
    unstable.tdesktop
  ];

  ddd.services = {
    xserver.desktopManager.gnome.enable = true;
  };
}
