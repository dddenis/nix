{ config, lib, pkgs, ... }:

let
  mkUser = i: username: {
    uid = 500 + i;
    home = "/Users/${username}";
    shell = pkgs.zsh;
    isHidden = false;
  };

in {
  environment.shells = [ pkgs.zsh ];

  networking = {
    dns = [ "8.8.8.8" ];
    knownNetworkServices = [ "Wi-Fi" ];
  };

  programs.zsh.enable = true;

  services.nix-daemon.enable = true;

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
        NetBIOSName = config.networking.hostName;
        ServerDescription = config.networking.hostName;
      };
    };

    keyboard = {
      enableKeyMapping = true;
      nonUS.remapTilde = true;
    };

    stateVersion = 4;
  };

  users = rec {
    knownUsers = builtins.attrNames users;

    nix.configureBuildUsers = true;

    users = lib.pipe config [
      lib.user.configs
      (lib.imap1 (i: userConfig:
        let inherit (userConfig.home) username;
        in lib.nameValuePair username (mkUser i username)))
      builtins.listToAttrs
    ];
  };
}
