{ config, pkgs, lib, inputs, outputs, ... }:

let
  homePath = if pkgs.stdenv.isDarwin then "/Users" else "/home";

  caches = {
    "https://cache.nixos.org" = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
    "https://cache.iog.io" =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
    "https://nix-community.cachix.org" =
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
  };

in
{
  config = lib.mkMerge [
    {
      nix.package = lib.mkDefault pkgs.nix;
      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        keep-outputs = true;
        keep-derivations = true;
        substituters = builtins.attrNames caches;
        trusted-public-keys = builtins.attrValues caches;
      };
      nix.registry = {
        config.flake = outputs;
        nixos.flake = inputs.nixos;
        nixpkgs.flake = inputs.nixpkgs;
      };

      home.sessionPath = [
        "$HOME/.local/bin"
      ];

      home.sessionVariables = {
        NIX_PATH = "nixos=${inputs.nixos}:nixpkgs=${inputs.nixpkgs}";
      };

      home.homeDirectory = "${homePath}/${config.home.username}";

      home.packages = with pkgs; [
        config.nix.package

        coreutils
        gnumake
        iosevka-bin

        unstable.devenv
      ];

      programs = {
        home-manager.enable = true;
        nix-index.enable = true;
        zoxide.enable = true;

        readline = {
          enable = true;
          variables = {
            editing-mode = "vi";
          };
        };
      };

      ddd.programs = {
        atool.enable = true;
        atuin.enable = true;
        bat.enable = true;
        delta.enable = true;
        direnv.enable = true;
        fd.enable = true;
        fzf.enable = true;
        git.enable = true;
        lazygit.enable = true;
        less.enable = true;
        lf.enable = true;
        process-compose.enable = true;
        ripgrep.enable = true;
        ssh.enable = true;
        tmux.enable = true;
        vim.enable = true;
        zsh.enable = true;
      };

      xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    }

    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        wl-clipboard
        xclip
      ];
    })

    (lib.mkIf pkgs.stdenv.isDarwin {
      ddd.programs = {
        homebrew.enable = true;
        karabiner.enable = false;
      };
    })
  ];
}
