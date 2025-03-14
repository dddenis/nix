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
    graphics.enable32Bit = true;
  };

  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

  programs = {
    steam.enable = true;
  };

  services = {
    gnome.at-spi2-core.enable = true;

    xserver = {
      enable = true;
      xkb.model = "hhk";
    };
  };

  ddd.hosts = {
    abra.enable = true;
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

  sops.defaultSopsFile = ./secrets.yaml;
}
