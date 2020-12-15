{ config, lib, pkgs, ... }:

let
  inherit (import ../lib { inherit lib; }) fs;

  overlays = fs.importDirRec {
    path = toString ./..;
    regex = "overlay.nix";
  };

  userConfig = config.home-manager.users.ddd;

in {
  imports = [
    <home-manager/nix-darwin>
    (import ../nix)
    (import ../services/lorri/darwin.nix { inherit userConfig; })
  ];

  nix = {
    buildCores = 8;
    maxJobs = 8;

    gc = {
      automatic = true;
      interval = { Weekday = 0; };
      options = "--delete-older-than 14d";
    };

    trustedUsers = [ "ddd" ];
  };

  nixpkgs = {
    inherit overlays;
    config.allowUnfree = true;
  };

  system = {
    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        "com.apple.mouse.tapBehavior" = 1;
      };

      dock = {
        autohide = true;
        mru-spaces = false;
        orientation = "left";
        tilesize = 32;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
      };

      smb = {
        NetBIOSName = "ddd-mcmakler";
        ServerDescription = "ddd-mcmakler";
      };
    };

    keyboard = {
      enableKeyMapping = true;
      nonUS.remapTilde = true;
    };
  };

  networking = {
    hostName = "ddd-mcmakler";
    dns = [ "8.8.8.8" ];
    knownNetworkServices = [ "Wi-Fi" ];
  };

  users = {
    knownUsers = [ "ddd" ];

    users.ddd = {
      uid = 501;
      description = "DDD";
      home = "/Users/ddd";
      shell = pkgs.zsh;
      isHidden = false;
    };
  };

  home-manager = {
    useUserPackages = true;
    users.ddd = args: {
      imports = [ ./home.nix ];
      nixpkgs = config.nixpkgs;
    };
  };

  fonts = {
    enableFontDir = true;
    fonts = lib.lists.unique userConfig.fonts.fonts;
  };

  environment = {
    darwinConfig = toString ./configuration.nix;
    shells = [ pkgs.zsh ];
    systemPackages = with pkgs; [ coreutils fd ];
    variables = userConfig.home.sessionVariables // { EDITOR = "vim"; };
  };

  programs = {
    nix-index.enable = true;
    zsh.enable = true;
  };

  services.nix-daemon.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
