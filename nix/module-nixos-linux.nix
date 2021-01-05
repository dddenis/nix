{ pkgs, ... }:

{
  boot = {
    cleanTmpDir = true;

    kernel.sysctl = { "vm.swappiness" = 60; };
    kernelPackages = pkgs.linuxPackages_latest;

    loader = {
      timeout = null;

      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = true;
        configurationLimit = 2;
        editor = false;
      };
    };
  };

  hardware = {
    enableAllFirmware = true;

    pulseaudio = {
      enable = true;
      support32Bit = true;
    };
  };

  networking = {
    useDHCP = false;
    interfaces = {
      enp34s0.useDHCP = true;
      wlo1.useDHCP = true;
    };
  };

  nix.gc.dates = "weekly";

  programs = {
    ssh.startAgent = true;
    vim.defaultEditor = true;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=50M
    SystemMaxFileSize=10M
  '';

  sound.enable = true;

  users.defaultUserShell = pkgs.zsh;
}
