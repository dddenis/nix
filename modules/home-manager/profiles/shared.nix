{ pkgs, ... }:

{
  config = {
    home.packages = with pkgs; [
      docker-compose
      gnumake
      insomnia
      lazydocker
      wl-clipboard
      xclip
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

    ddd = {
      programs = {
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

      services = {
        safeeyes.enable = true;
      };
    };
  };
}
