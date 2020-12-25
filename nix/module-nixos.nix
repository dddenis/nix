{ config, lib, pkgs, ... }:

let
  caches = {
    "https://hydra.iohk.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
  };

  normalUsers = builtins.attrNames
    (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);

in {
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

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  networking = {
    useDHCP = false;
    interfaces = {
      enp34s0.useDHCP = true;
      wlo1.useDHCP = true;
    };
  };

  nix = {
    binaryCaches = builtins.attrNames caches;
    binaryCachePublicKeys = builtins.attrValues caches;
    trustedUsers = [ "root" ] ++ normalUsers;
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs = {
    overlays = [ (import ../overlays-compat/overlays.nix) ];
    config.allowUnfree = true;
  };

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
