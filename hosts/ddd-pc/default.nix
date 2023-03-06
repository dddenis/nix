{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  profiles.desktop.enable = true;

  boot.blacklistedKernelModules = [ "sp5100_tco" ];
  boot.extraModprobeConfig = ''
    options iwlmvm power_scheme=1

    options iwlwifi 11n_disable=1
    options iwlwifi bt_coex_active=0
    options iwlwifi d0i3_disable=1
    options iwlwifi lar_disable=1
    options iwlwifi power_save=0
    options iwlwifi swcrypto=0
    options iwlwifi uapsd_disable=1
  '';

  hardware = {
    bluetooth = {
      enable = true;
      disabledPlugins = [ "sap" ];
    };

    cpu.amd.updateMicrocode = true;
    opengl.driSupport32Bit = true;
  };

  services = {
    gnome.at-spi2-core.enable = true;

    xserver = {
      enable = true;
      xkbModel = "hhk";
    };
  };

  ddd.services = {
    xserver.desktopManager.gnome.enable = true;
  };

  users.users.ddd = {
    name = "ddd";
    isNormalUser = true;
    initialPassword = "nixos";
    extraGroups = [ "docker" "wheel" ];
  };

  home-manager.users.ddd = {
    home.packages = with pkgs; [
      chromium
      firefox-wayland
      inkscape
      krita
      slack

      unstable.tdesktop
    ];

    ddd = {
      programs = {
        spotify.enable = true;
      };

      services = {
        xserver.desktopManager.gnome.enable = true;
      };
    };

    xdg.mimeApps.defaultApplications = {
      "application/xhtml+xml" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "text/xml" = "firefox.desktop";
      "x-scheme-handler/ftp" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
