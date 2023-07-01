{ config, lib, pkgs, inputs, outputs, ... }:

let
  caches = {
    "https://cache.iog.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
    "https://nix-community.cachix.org" =
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
  };

in
{
  config = {
    hardware.enableAllFirmware = true;

    boot.tmp.cleanOnBoot = true;

    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.editor = false;
    boot.loader.systemd-boot.configurationLimit = 10;

    system = {
      configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
      stateVersion = outputs.stateVersion;
    };

    nix = {
      nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      settings = {
        trusted-users = [ "root" "@wheel" ];
        substituters = builtins.attrNames caches;
        trusted-public-keys = builtins.attrValues caches;
      };
    };

    nixpkgs = {
      overlays = [ outputs.overlays.default ];
      config.allowUnfree = true;
    };

    users.defaultUserShell = pkgs.zsh;

    environment.variables = {
      EDITOR = "nvim";
    };

    virtualisation.docker.enable = true;

    programs = {
      ssh.startAgent = true;
      zsh.enable = true;
    };

    services.journald.extraConfig = ''
      SystemMaxUse=50M
      SystemMaxFileSize=10M
    '';

    services.xserver = {
      layout = "us,ru";
      xkbOptions = "ctrl:nocaps,grp:alt_space_toggle";
    };

    ddd.services.kmonad.enable = true;

    time.timeZone = "Europe/Berlin";
  };
}
