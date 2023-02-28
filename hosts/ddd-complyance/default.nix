{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-10th-gen
    inputs.ipu6.nixosModules.default
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "i915.enable_psr=0" ];

  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/0b0e613b-6864-4c2d-9a5f-ce6f078ac452";
      preLVM = true;
      allowDiscards = true;
    };
  };

  hardware.ipu6.enable = true;
  hardware.ipu6.ipuVersion = "ipu6ep";

  hardware.bluetooth = {
    enable = true;
    disabledPlugins = [ "sap" ];
  };

  hardware.video.hidpi.enable = true;

  virtualisation.docker.enable = true;

  fonts = {
    fonts = with pkgs; [ ddd.iosevka-font ddd.iosevka-nerd-font ];

    fontconfig.defaultFonts = {
      monospace = lib.mkBefore [ "Iosevka DDD" "Iosevka Nerd Font Mono" ];
    };
  };

  services = {
    fprintd.enable = true;
    gnome.at-spi2-core.enable = true;

    xserver = {
      enable = true;

      layout = "us,ru";
      xkbModel = "hhk";
      xkbOptions = "ctrl:nocaps,grp:alt_space_toggle";
    };
  };

  ddd.services = {
    kmonad.enable = true;
    xserver.desktopManager.gnome.enable = true;
  };

  users.users.ddd = {
    name = "ddd";
    isNormalUser = true;
    initialPassword = "nixos";
    extraGroups = [ "docker" "wheel" ];

    packages = with pkgs; [
      docker-compose
      firefox-wayland
      gnumake
      htop
      insomnia
      lazydocker
      wl-clipboard
      xclip

      unstable.tdesktop
      unstable.teams-for-linux
    ];
  };

  home-manager.users.ddd.ddd.programs = {
    alacritty.enable = true;
    atool.enable = true;
    bat.enable = true;
    direnv.enable = true;
    fd.enable = true;
    fzf.enable = true;
    git.enable = true;
    lazygit.enable = true;
    less.enable = true;
    nnn.enable = true;
    ripgrep.enable = true;
    spotify.enable = true;
    tmux.enable = true;
    vim.enable = true;
    zsh.enable = true;
  };

  home-manager.users.ddd.ddd.services = {
    safeeyes.enable = true;
    xserver.desktopManager.gnome.enable = true;
  };
}
