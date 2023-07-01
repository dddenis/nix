{ config, lib, pkgs, inputs, outputs, ... }:

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
