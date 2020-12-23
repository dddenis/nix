{ config, lib, pkgs, ... }:

let overlays = import ../overlays-compat/overlays.nix;

in {
  imports = [
    <home-manager/nixos>
    ../nix
    ../services/kmonad/nixos.nix
    ./hardware-configuration.nix
  ];

  nix = {
    nixPath = [
      "nixpkgs=${toString <nixpkgs>}"
      "nixos-config=${toString ./configuration.nix}"
      "nixpkgs-overlays=${toString ../overlays-compat}"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    trustedUsers = [ "ddd" ];
  };

  nixpkgs = {
    overlays = [ overlays ];
    config.allowUnfree = true;
  };

  boot = {
    cleanTmpDir = true;

    kernel.sysctl = { "vm.swappiness" = 60; };
    kernelPackages = pkgs.linuxPackages_latest;
    blacklistedKernelModules = [ "sp5100_tco" ];

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

  networking = {
    hostName = "ddd-pc";

    firewall.allowedUDPPorts = [
      # spotify
      5353

      # unity
      34997
      54997
    ];

    useDHCP = false;
    interfaces = {
      enp34s0.useDHCP = true;
      wlo1.useDHCP = true;
    };
  };

  sound.enable = true;

  time.timeZone = "Europe/Berlin";

  hardware = {
    enableAllFirmware = true;

    bluetooth.enable = true;
    cpu.amd.updateMicrocode = true;
    opengl.driSupport32Bit = true;

    pulseaudio = {
      enable = true;
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      package = pkgs.pulseaudioFull;
      support32Bit = true;
    };
  };

  users = {
    defaultUserShell = pkgs.zsh;

    users.ddd = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.ddd = import ./home.nix;
  };

  fonts.fontconfig.defaultFonts = {
    monospace =
      lib.mkBefore [ "Iosevka DDD Extended" "Iosevka Nerd Font Mono" ];
  };

  environment.systemPackages = with pkgs; [
    fd
    git
    htop
    pavucontrol
    ripgrep
    unzip
    xclip
  ];

  programs = {
    adb.enable = true;
    ssh.startAgent = true;
    vim.defaultEditor = true;
  };

  services = {
    safeeyes.enable = true;

    journald.extraConfig = ''
      SystemMaxUse=50M
      SystemMaxFileSize=10M
    '';

    xserver = {
      enable = true;

      layout = "us,ru";
      xkbModel = "hhk";
      xkbOptions = "ctrl:nocaps,grp:alt_space_toggle";

      displayManager.sddm.enable = true;
      desktopManager.plasma5.enable = true;
    };
  };

  systemd.services.bluetooth.serviceConfig.ExecStart =
    [ "" "${pkgs.bluez}/bin/bluetoothd --noplugin=sap" ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?
}
