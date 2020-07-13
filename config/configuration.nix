{ config, lib, pkgs, ... }:

let overlays = import ../overlays-compat/overlays.nix;

in {
  imports = [ <home-manager/nixos> ./hardware-configuration.nix ];

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

    trustedUsers = [ "root" "ddd" ];
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

    firewall.allowedUDPPorts = [ 34997 54997 ];

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

  location.provider = "geoclue2";

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
    blueman.enable = true;
    redshift.enable = true;
    safeeyes.enable = true;

    journald.extraConfig = ''
      SystemMaxUse=50M
      SystemMaxFileSize=10M
    '';

    xserver = {
      enable = true;

      desktopManager.xterm.enable = true;

      displayManager = {
        defaultSession = "xterm";

        lightdm = {
          greeters = {
            gtk.enable = false;

            mini = {
              enable = true;
              user = "ddd";
              extraConfig = ''
                [greeter]
                show-password-label = false
                password-alignment = left

                [greeter-theme]
                background-color = "#3B4252"
                border-width = 0px
                window-color = "#2E3440"
                password-color = "#ECEFF4"
                password-background-color = "#4C566A"
              '';
            };
          };
        };
      };
    };
  };

  system.autoUpgrade.enable = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.03"; # Did you read the comment?
}
