{ config, lib, options, pkgs, ... }:

let
  caches = {
    "https://hydra.iohk.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
    "https://nix-community.cachix.org" =
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
  };

in {
  options.profiles.shared.enable = lib.mkEnableOption "shared profile";

  config = lib.mkIf config.profiles.shared.enable {
    hardware.enableAllFirmware = true;

    boot.cleanTmpDir = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.editor = false;
    boot.loader.systemd-boot.enable = true;

    networking.useDHCP = false;

    nix = {
      extraOptions = ''
        experimental-features = nix-command flakes
      '';

      settings = {
        trusted-users = [ "root" config.user.name ];
        substituters = builtins.attrNames caches;
        trusted-public-keys = builtins.attrValues caches;
      };
    };

    nixpkgs.config.allowUnfree = true;

    user = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    users = {
      defaultUserShell = pkgs.zsh;
      users."${config.user.name}" = lib.mkAliasDefinitions options.user;
    };

    programs = {
      ssh.startAgent = true;
      vim.defaultEditor = true;
    };

    services.journald.extraConfig = ''
      SystemMaxUse=50M
      SystemMaxFileSize=10M
    '';

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      verbose = true;

      extraSpecialArgs = { name = config.user.name; };
      users."${config.user.name}" = lib.mkAliasDefinitions options.hm;
    };

    time.timeZone = "Europe/Berlin";
  };
}
