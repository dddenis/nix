{ config, lib, pkgs, inputs, outputs, ... }:

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

    system = {
      configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
      stateVersion = outputs.stateVersion;
    };

    nix = {
      extraOptions = ''
        experimental-features = nix-command flakes
        keep-outputs = true
        keep-derivations = true
      '';

      nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      registry = {
        config.flake = outputs;
        nixos.flake = inputs.nixos;
        nixpkgs.flake = inputs.nixpkgs;
      };

      settings = {
        trusted-users = [ "root" ] ++ normalUserNames;
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

    fonts = {
      fonts = with pkgs; [ ddd.iosevka-font ddd.iosevka-nerd-font ];

      fontconfig.defaultFonts = {
        monospace = lib.mkBefore [ "Iosevka DDD" "Iosevka Nerd Font Mono" ];
      };
    };

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

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      verbose = true;
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [ outputs.homeModules.default ];
    };

    time.timeZone = "Europe/Berlin";
  };
}
