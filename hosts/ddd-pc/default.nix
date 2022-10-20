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
    bluetooth.enable = true;
    cpu.amd.updateMicrocode = true;
    opengl.driSupport32Bit = true;
  };

  virtualisation.docker.enable = true;

  networking.interfaces = {
    enp34s0.useDHCP = true;
    wlo1.useDHCP = true;
  };

  fonts = {
    fonts = with pkgs; [ iosevka-ddd-font iosevka-nerd-font ];

    fontconfig.defaultFonts = {
      monospace = lib.mkBefore [ "Iosevka DDD" "Iosevka Nerd Font Mono" ];
    };
  };

  programs = {
    alacritty.enable' = true;
    atool.enable' = true;
    bat.enable' = true;
    direnv.enable' = true;
    fzf.enable' = true;
    git.enable' = true;
    lazygit.enable' = true;
    less.enable' = true;
    nnn.enable' = true;
    ripgrep.enable' = true;
    spotify.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    zsh.enable' = true;
  };

  services = {
    gnome.at-spi2-core.enable = true;
    kmonad.enable' = true;
    safeeyes.enable' = true;

    xserver = {
      enable = true;

      layout = "us,ru";
      xkbModel = "hhk";
      xkbOptions = "ctrl:nocaps,grp:alt_space_toggle";

      desktopManager.gnome.enable' = true;
    };
  };

  systemd.services.bluetooth.serviceConfig.ExecStart =
    [ "" "${pkgs.bluez}/bin/bluetoothd --noplugin=sap" ];

  user = {
    name = "ddd";
    extraGroups = [ "docker" ];

    packages = with pkgs; [
      chromium
      docker-compose
      fd
      firefox-wayland
      gnumake
      htop
      inkscape
      insomnia
      krita
      lazydocker
      slack
      unstable.tdesktop
      xclip
    ];
  };

  home.enable' = true;

  hm.xdg.mimeApps.defaultApplications = {
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "text/xml" = "firefox.desktop";
    "x-scheme-handler/ftp" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };
}
