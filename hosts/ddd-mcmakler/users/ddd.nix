{ lib, pkgs, ... }:

{
  fonts.enable' = true;

  home = {
    enable' = true;

    packages = with pkgs; [ fd htop niv ];
  };

  programs = {
    alacritty.enable' = true;
    bat.enable' = true;
    direnv.enable' = true;
    emacs.enable' = true;
    fzf.enable' = true;
    git.enable' = true;
    less.enable' = true;
    nnn.enable' = true;
    ripgrep.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;
    zsh.enable' = true;
  };
}
