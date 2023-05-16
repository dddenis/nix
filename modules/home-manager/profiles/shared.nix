{ config, pkgs, lib, inputs, outputs, ... }:

let
  homePath = if pkgs.stdenv.isDarwin then "/Users" else "/home";

in
{
  config = lib.mkMerge [
    {
      nix.package = lib.mkDefault pkgs.nix;
      nix.extraOptions = ''
        experimental-features = nix-command flakes
        keep-outputs = true
        keep-derivations = true
      '';
      nix.registry = {
        config.flake = outputs;
        nixos.flake = inputs.nixos;
        nixpkgs.flake = inputs.nixpkgs;
      };

      home.homeDirectory = "${homePath}/${config.home.username}";

      home.packages = with pkgs; [
        coreutils
        gnumake
        iosevka-bin
        lazydocker
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
        alacritty.enable = true;
        atool.enable = true;
        bat.enable = true;
        direnv.enable = true;
        fd.enable = true;
        fzf.enable = true;
        git.enable = true;
        lazygit.enable = true;
        less.enable = true;
        lf.enable = true;
        ripgrep.enable = true;
        ssh.enable = true;
        tmux.enable = true;
        vim.enable = true;
        wezterm.enable = true;
        zsh.enable = true;
      };

      xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    }

    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        docker
        insomnia
        wl-clipboard
        xclip
      ];

      ddd.services = {
        safeeyes.enable = true;
      };
    })

    (lib.mkIf pkgs.stdenv.isDarwin {
      ddd.programs = {
        homebrew.enable = true;
        karabiner.enable = true;
      };
    })
  ];
}
