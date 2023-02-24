{ config, lib, options, pkgs, inputs, outputs, ... }:

let
  caches = {
    "https://cache.iog.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
    "https://nix-community.cachix.org" =
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
  };

  normalUserNames =
    let normalUsers = lib.filterAttrs (_: user: user.isNormalUser) config.users.users;
    in builtins.attrNames normalUsers;

in
{
  config = {
    hardware.enableAllFirmware = true;

    boot.cleanTmpDir = true;

    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.editor = false;
    boot.loader.systemd-boot.configurationLimit = 10;

    nix = {
      extraOptions = ''
        experimental-features = nix-command flakes
        keep-outputs = true
        keep-derivations = true
      '';

      settings = {
        trusted-users = [ "root" ] ++ normalUserNames;
        substituters = builtins.attrNames caches;
        trusted-public-keys = builtins.attrValues caches;
      };
    };

    nixpkgs.config.allowUnfree = true;

    users.defaultUserShell = pkgs.zsh;

    environment.variables = {
      EDITOR = "nvim";
    };

    programs = {
      ssh.startAgent = true;
      zsh.enable = true;
    };

    services.journald.extraConfig = ''
      SystemMaxUse=50M
      SystemMaxFileSize=10M
    '';

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      verbose = true;
    };

    time.timeZone = "Europe/Berlin";
  };
}
