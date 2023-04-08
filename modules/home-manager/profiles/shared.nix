{ pkgs, lib, ... }:

{
  config = lib.mkMerge [
    {
      home.packages = with pkgs; [
        docker
        gnumake
        lazydocker
      ];

      programs = {
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
        tmux.enable = true;
        vim.enable = true;
        zsh.enable = true;
      };
    }

    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        insomnia
        wl-clipboard
        xclip
      ];

      ddd.services = {
        safeeyes.enable = true;
      };
    })
  ];
}
