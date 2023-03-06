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

  services.fprintd.enable = true;
  services.gnome.at-spi2-core.enable = true;

  services.xserver = {
    enable = true;
    xkbModel = "hhk";
  };

  ddd.services.xserver.desktopManager.gnome.enable = true;

  users.users.ddd = {
    name = "ddd";
    isNormalUser = true;
    initialPassword = "nixos";
    extraGroups = [ "docker" "wheel" ];
  };

  home-manager.users.ddd = {
    home.packages = with pkgs; [
      firefox-wayland
      gnumake

      unstable.tdesktop
      unstable.teams-for-linux
    ];

    programs = {
      git.includes = [
        {
          condition = "hasconfig:remote.*.url:git@github.com:complyance/**";
          contents = {
            user.email = "denis.goncharenko@complyance.com";
          };
        }
      ];
    };

    ddd = {
      programs = {
        spotify.enable = true;
      };

      services = {
        xserver.desktopManager.gnome.enable = true;
      };
    };
  };
}
